import Foundation
import Yams
import PathKit

public struct MintfileYAML {
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

        let packages = packageEntry.map(PackageReference.init(yamlEntry:))

        self.packages = packages
    }
}
