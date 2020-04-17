import Foundation
import PathKit

public class PackageReference {
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
        case unknown

        var string: String {
            switch self {
            case .github(repo: let name), .git(location: let name):
                return name
            case .unknown:
                fatalError()
            }
        }
    }

    public enum Revision {
        case version(major: UInt, minor: UInt, patch: UInt)
        case tag(String)
        case branch(String)
        case unknown(String?)

        var string: String {
            switch self {
            case .branch(let name), .tag(let name):
                return name
            case .version(major: let major, minor: let minor, patch: let patch):
                return "\(major).\(minor).\(patch)"
            case .unknown(let text):
                return text ?? ""
            }
        }
    }

    @available(*, unavailable)
    public init(repo: String, version: String = "") {
//        self.repo = repo
//        self.version = version

        fatalError()
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
        if packageParts.count == 3 {
            repo = [packageParts[0], packageParts[1]].joined(separator: "@")
            version = packageParts[2]
            location = { fatalError() }()
            revision = { fatalError() }()

        } else if packageParts.count == 2 {
            if packageParts[1].contains(":") {
                repo = [packageParts[0], packageParts[1]].joined(separator: "@")
                version = ""

                location = { fatalError() }()
                revision = { fatalError() }()
            } else if packageParts[0].contains("ssh://") {
                repo = [packageParts[0], packageParts[1]].joined(separator: "@")
                version = ""
                location = { fatalError() }()
                revision = { fatalError() }()
            } else {
                repo = packageParts[0]
                version = packageParts[1]

                location = .github(repo: packageParts[0])
                revision = .unknown(packageParts[1])
            }
        } else {
            repo = package
            version = ""

            location = { fatalError() }()
            revision = { fatalError() }()
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
        if let url = URL(string: repo), url.scheme != nil {
            return url.absoluteString
        } else {
            if repo.contains("@") {
                return repo
            } else if repo.contains("github.com") {
                return "https://\(repo).git"
            } else if repo.components(separatedBy: "/").first!.contains(".") {
                return "https://\(repo)"
            } else {
                return "https://github.com/\(repo).git"
            }
        }
    }

    var repoPath: String {
        return gitPath
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
