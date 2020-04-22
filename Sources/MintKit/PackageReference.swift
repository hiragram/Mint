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

    public enum Location {
        public typealias StringLiteralType = String

        case github(repo: String)
        case git(location: String)
        case localGit(path: String)
        case localPackage(path: String)
        case legacyStyle(String)
        case unknown

        var string: String {
            switch self {
            case .github(repo: let name), .git(location: let name), .localGit(path: let name), .localPackage(path: let name):
                return name
            case .legacyStyle(let legacyDefinitionText):
                return legacyDefinitionText
            case .unknown:
                fatalError()
            }
        }

        var isGitRepository: Bool {
            switch self {
            case .git(location: _), .github(repo: _), .localGit(path: _), .legacyStyle(_):
                return true
            case .localPackage(path: _), .unknown:
                return false
            }
        }
    }

    public enum Revision {
        case tag(String)
        case branch(String)
        case commit(String)
        case unknown(String?)

        var string: String {
            switch self {
            case .branch(let name), .tag(let name), .commit(let name):
                return name
            case .unknown(let text):
                return text ?? ""
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

    public convenience init(yamlEntry: [String: Any]) {
        let locationAndRevisionKeys: [String: [String]] = [
            "github": [
                "tag", "branch", "commit",
            ],
            "git": [
                "tag", "branch", "commit",
            ],
            "local_git": [
                "tag", "branch", "commit",
            ],
            "local_package": [

            ],
        ]

        // Make sure only one location key is contained.
        let locationKeys = yamlEntry.keys
            .filter { locationAndRevisionKeys.keys.contains($0) }

        guard locationKeys.count == 1 else {
            fatalError("include exact one location key.")
        }

        let locationKey = locationKeys.first!

        let revisionKeys = yamlEntry.keys
            .filter { locationAndRevisionKeys[locationKey]!.contains($0) }

        guard revisionKeys.count <= 1 else {
            fatalError("more than 1 revision key found.")
        }

        let revisionKey = revisionKeys.first

        let location: Location
        let locationValue = yamlEntry[locationKey] as! String
        switch locationKey {
        case "github":
            location = .github(repo: locationValue)
        case "git":
            location = .git(location: locationValue)
        case "local_git":
            location = .localGit(path: locationValue)
        case "local_package":
            location = .localPackage(path: locationValue)
        default:
            fatalError()
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
                fatalError()
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

    public var gitPath: String? {
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
            case .localGit(path: let gitPath):
                return gitPath
            case .localPackage(path: _):
                return nil
            case .legacyStyle(let repo):
                if repo.contains("@") {
                    return repo
                } else if repo.contains("github.com") {
                    return "https://\(repo).git"
                } else if repo.components(separatedBy: "/").first!.contains(".") {
                    return "https://\(repo)"
                } else {
                    return "https://github.com/\(repo).git"
                }
            case .unknown:
                fatalError()
            }
        }
    }

    var repoPath: String {
        return (gitPath ?? location.string)
            .components(separatedBy: "://").last!
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".git", with: "")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "_")
    }
}

extension PackageReference: Equatable {
    public static func == (lhs: PackageReference, rhs: PackageReference) -> Bool {
        return lhs.repo == rhs.repo && lhs.version == rhs.version
    }
}
