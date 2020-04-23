import Foundation
import PathKit

public class PackageReference: CustomStringConvertible {
    public var description: String {
        if version.isEmpty {
            return repo
        } else {
            return "\(repo)@\(version)"
        }
    }

    public var location: Location
    public var revision: Revision?

    public var repo: String {
        location.string
    }

    public var version: String {
        revision?.string ?? ""
    }

    public enum Location: Equatable {
        public typealias StringLiteralType = String

        case github(repo: String)
        case git(location: String)
        case localGit(absolutePath: String)
        case localPackage(absolutePath: String)
        case legacyStyle(String)

        var string: String {
            switch self {
            case .github(repo: let name):
                return "https://github.com/\(name).git"
            case .git(location: let name), .localGit(absolutePath: let name), .localPackage(absolutePath: let name):
                return name
            case .legacyStyle(let legacyDefinitionText):
                if legacyDefinitionText.contains("@") {
                    return legacyDefinitionText
                } else if legacyDefinitionText.contains("github.com") {
                    return "https://\(legacyDefinitionText).git"
                } else if legacyDefinitionText.components(separatedBy: "/").first!.contains(".") {
                    return "https://\(legacyDefinitionText)"
                } else {
                    return "https://github.com/\(legacyDefinitionText).git"
                }
            }
        }

        var isGitRepository: Bool {
            switch self {
            case .git(location: _), .github(repo: _), .localGit(absolutePath: _), .legacyStyle(_):
                return true
            case .localPackage(absolutePath: _):
                return false
            }
        }
    }

    public enum Revision: Equatable {
        case tag(String)
        case branch(String)
        case commit(String)

        var string: String {
            switch self {
            case .branch(let name), .tag(let name), .commit(let name):
                return name
            }
        }
    }

    public init(repo: String, version: String = "") {
        self.location = .legacyStyle(repo)
        self.revision = .tag(version)
    }

    public init(location: Location, revision: Revision?) {
        self.location = location
        self.revision = revision
    }

    public convenience init(package: String) {
        let packageParts = package.components(separatedBy: "@")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let repo: String
        let version: String
        let location: Location
        let revision: Revision?

        // This means `package` looks like "git@github.com:yonaskolb/Mint.git@0.0.1"
        if packageParts.count == 3 {
            repo = [packageParts[0], packageParts[1]].joined(separator: "@")
            version = packageParts[2]
            location = .legacyStyle(repo)
            revision = .tag(version)

        } else if packageParts.count == 2 {
            // This means `package` looks like "git@github.com:yonaskolb/Mint.git"
            if packageParts[1].contains(":") {
                repo = [packageParts[0], packageParts[1]].joined(separator: "@")
                version = ""

                location = .legacyStyle(repo)
                revision = nil
            } else if packageParts[0].contains("ssh://") {
                repo = [packageParts[0], packageParts[1]].joined(separator: "@")
                version = ""
                location = .legacyStyle(repo)
                revision = nil
            } else {
                repo = packageParts[0]
                version = packageParts[1]

                location = .legacyStyle(repo)
                revision = .tag(version)
            }
        } else {
            repo = package
            version = ""

            location = .legacyStyle(package)
            revision = nil
        }
        self.init(location: location, revision: revision)
    }

    public convenience init(yamlEntry: [String: Any]) throws {
        let locationSpecifierKeys = ["github", "git", "local_git", "local_package"]
        let revisionSpecifierKeys = ["tag", "branch", "commit"]

        // Make sure only one location key is contained.
        let locationKeys = yamlEntry.keys
            .filter { locationSpecifierKeys.contains($0) }

        guard locationKeys.count <= 1 else {
            throw MintError.locationDuplicated(yamlEntry)
        }

        guard let locationKey = locationKeys.first else {
            throw MintError.locationSpecifierNotFound(yamlEntry)
        }

        let revisionKeys = yamlEntry.keys
            .filter { revisionSpecifierKeys.contains($0) }

        let revisionKey = revisionKeys.first

        let location: Location
        let locationValue = yamlEntry[locationKey] as! String
        switch locationKey {
        case "github":
            location = .github(repo: locationValue)
        case "git":
            location = .git(location: locationValue)
        case "local_git":
            location = .localGit(absolutePath: locationValue)
        case "local_package":
            location = .localPackage(absolutePath: locationValue)
            let unnecessaryRevisionSpecifiers = yamlEntry.keys.filter { revisionSpecifierKeys.contains($0) }
            guard unnecessaryRevisionSpecifiers.isEmpty else {
                throw MintError.localPackageNeverHaveRevisionSpecifier(location, unnecessaryRevisionSpecifiers)
            }
        default:
            throw MintError.locationSpecifierNotFound(yamlEntry)
        }

        guard revisionKeys.count <= 1 else {
            throw MintError.revisionDuplicated(location, revisionKeys)
        }

        let revision: Revision?
        if let revisionValue = revisionKey.flatMap({ yamlEntry[$0] as? String }) {
            switch revisionKey {
            case "tag":
                revision = .tag(revisionValue)
            case "branch":
                revision = .branch(revisionValue)
            case "commit":
                revision = .commit(revisionValue)
            default:
                revision = nil
            }
        } else {
            revision = nil
        }

        self.init(location: location, revision: revision)
    }

    public var namedVersion: String {
        return "\(name) \(version)"
    }

    public var name: String {
        return repo.components(separatedBy: "/").last!.replacingOccurrences(of: ".git", with: "")
    }

    public var gitPath: String {
//        guard location.isGitRepository else {
//            fatalError()
//        }
        if let url = URL(string: repo), url.scheme != nil {
            return url.absoluteString
        } else {
            switch location {
            case .github(repo: let repo):
                return "https://github.com/\(repo).git"
            case .git(location: let gitPath):
                return gitPath
            case .localGit(absolutePath: let gitPath):
                return gitPath
            case .localPackage(absolutePath: _):
                return ""
            case .legacyStyle(_):
                return location.string
            }
        }
    }

    public var versionCouldBeSHA: Bool {
        switch version {
        case "master", "develop":
            return false
        default:
            let characterSet = CharacterSet.letters.union(.decimalDigits)
            if version.rangeOfCharacter(from: characterSet.inverted) != nil {
                return false
            }
            return true
        }
    }

    var repoPath: String {
        location.string
            .components(separatedBy: "://").last!
            .components(separatedBy: "@").last!
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".git", with: "")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "_")
    }
}

extension PackageReference: Equatable {
    public static func == (lhs: PackageReference, rhs: PackageReference) -> Bool {
//        return lhs.repo == rhs.repo && lhs.version == rhs.version
        return lhs.location == rhs.location && lhs.revision == lhs.revision
    }
}

extension PackageReference {
    func preparePackageDictionaryCommand() -> String {
        let specificRevision = revision ?? .branch("master")

        switch location {
        case .legacyStyle:
            return "git clone --depth 1 -b \(version) \(gitPath) \(repoPath)"
        case .git, .github:
            switch specificRevision {
            case .branch(let name), .tag(let name):
                return "git clone --depth 1 -b \(name) \(gitPath) \(repoPath)"
            case .commit(let name):
                return "git clone \(gitPath) \(repoPath) ; cd \(repoPath) ; git checkout \(name) ; cd -"
            }
        case .localGit(absolutePath: let path):
            switch specificRevision {
            case .branch(let name), .tag(let name):
                return "git clone -b \(name) -l \(path) \(repoPath)"
            case .commit(let name):
                return "git clone -l \(path) \(repoPath) ; cd \(repoPath) ; git checkout \(name) ; cd -"
            }
        case .localPackage(absolutePath: let path):
            return "cp -r \(path) \(repoPath)"
        }
    }
}
