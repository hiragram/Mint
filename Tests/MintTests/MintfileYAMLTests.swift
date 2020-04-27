@testable import MintKit
import PathKit
import XCTest

class MintfileYAMLTests: XCTestCase {
    func testMintfileYAMLParse() throws {
        let mintfile = try MintfileYAML(path: mintFileYamlFixture)

        XCTAssertEqual(
            mintfile.packages,
            [
                PackageReference(location: .github(repo: "yonaskolb/mint"), revision: .tag("0.14.2")),
                PackageReference(location: .github(repo: "yonaskolb/mint"), revision: .branch("master")),
                PackageReference(location: .github(repo: "yonaskolb/mint"), revision: .commit("b0c0837")),
                PackageReference(location: .git(location: "git@github.com:yonaskolb/Mint.git"), revision: .tag("0.14.2")),
                PackageReference(location: .git(location: "git@github.com:yonaskolb/Mint.git"), revision: .branch("master")),
                PackageReference(location: .git(location: "git@github.com:yonaskolb/Mint.git"), revision: .commit("b0c0837")),
                PackageReference(location: .localGit(absolutePath: Path("~/Development/Mint_localrepo").normalize().absolute().string), revision: .tag("0.14.2")),
                PackageReference(location: .localGit(absolutePath: Path("~/Development/Mint_localrepo").normalize().absolute().string), revision: .branch("master")),
                PackageReference(location: .localGit(absolutePath: Path("~/Development/Mint_localrepo").normalize().absolute().string), revision: .commit("b0c0837")),
                PackageReference(location: .localPackage(absolutePath: (mintFileYamlFixture.parent() + Path("DummySwiftPackage")).string), revision: nil),
            ]
        )
    }

    func testLocalPackagesNeverHaveRevisionSpecifier() throws {
        let location = PackageReference.Location.localPackage(absolutePath: "/path/to/package")

        expectError(MintError.localPackageNeverHaveRevisionSpecifier(location, ["commit"].sorted())) {
            _ = try PackageReference(yamlEntry:
                [
                    "local_package": "/path/to/package",
                    "commit": "abcdefg",
                ]
            )
        }

        expectError(MintError.localPackageNeverHaveRevisionSpecifier(location, ["commit", "tag"].sorted())) {
            _ = try PackageReference(yamlEntry:
                [
                    "local_package": "/path/to/package",
                    "commit": "abcdefg",
                    "tag": "1.2.3"
                ]
            )
        }
    }

    func testPackagesNeverHaveMoreThanOneRevisionSpecifier() throws {
        let github = PackageReference.Location.github(repo: "user/repo")
        expectError(MintError.revisionDuplicated(github, ["commit", "tag"].sorted())) {
            _ = try PackageReference(yamlEntry:
                [
                    "github": "user/repo",
                    "commit": "abcdefg",
                    "tag": "1.2.3",
                    "otherkey": "othervalue",
                ]
            )
        }

        let git = PackageReference.Location.git(location: "git@example.com:user/repo.git")
        expectError(MintError.revisionDuplicated(git, ["commit", "tag"].sorted())) {
            _ = try PackageReference(yamlEntry:
                [
                    "git": "git@example.com:user/repo.git",
                    "commit": "abcdefg",
                    "tag": "1.2.3",
                    "otherkey": "othervalue",
                ]
            )
        }
    }

    func testPackageMustHaveExactOneLocationSpecifier() {
        expectError(MintError.locationSpecifierNotFound([:])) {
            _ = try PackageReference(yamlEntry: [:])
        }

        expectError(MintError.locationDuplicated(["github": "user/repo", "git": "git@example.com:user/repotest1"])) {
            _ = try PackageReference(yamlEntry: ["github": "user/repo", "git": "git@example.com:user/repotest1"])
        }
    }
}
