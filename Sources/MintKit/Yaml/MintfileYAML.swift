import Foundation
import Yams
import PathKit

public struct MintfileYAML: MintfileProtocol {
    let packages: [PackageReference]

    public func package(for repo: String) -> PackageReference? {
        packages.first {
            $0.repo.lowercased().contains(repo.lowercased())
        }
    }

    public init(path: Path) throws {
        guard path.exists else {
            throw MintError.mintfileNotFound(path.string)
        }
        let contents: String = try path.read()

        guard let yaml = try Yams.load(yaml: contents) as? [String: Any] else {
            fatalError()
        }

        let packageEntry = yaml["packages"] as! [[String: Any]]

        let pathFixedPackageEntry = packageEntry.map { (packageRow) -> [String: Any] in
            packageRow.reduce(into: [String: Any]()) { (result, keyValue) in
                if Self.keysContainPath.contains(keyValue.key) {
                    guard let pathString = keyValue.value as? String else {
                        fatalError()
                    }

                    let fixedPath: Path
                    let rawPath = Path(pathString).normalize()
                    if rawPath.isAbsolute {
                        fixedPath = rawPath
                    } else {
                        fixedPath = path.absolute().parent() + rawPath
                    }
                    result[keyValue.key] = fixedPath.string
                } else {
                    result[keyValue.key] = keyValue.value
                }
            }
        }

        let packages = try pathFixedPackageEntry.map(PackageReference.init(yamlEntry:))

        self.packages = packages
    }

    private static let keysContainPath: [String] = [
        "local_git",
        "local_package"
    ]
}
