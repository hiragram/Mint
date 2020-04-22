import Foundation
import SwiftCLI

public enum MintError: Error, CustomStringConvertible, Equatable, LocalizedError {
    case packageNotFound(String)
    case repoNotFound(String)
    case missingExecutable(PackageReference)
    case invalidExecutable(String)
    case cloneError(PackageReference)
    case mintfileNotFound(String)
    case packageResolveError(PackageReference)
    case packageBuildError(PackageReference)
    case packageReadError(String)
    case packageNotInstalled(PackageReference)
    case locationDuplicated([String: Any])
    case revisionDuplicated(PackageReference.Location, [String])
    case localPackageNeverHaveRevisionSpecifier(PackageReference.Location, [String])
    case locationSpecifierNotFound([String: Any])

    public var description: String {
        switch self {
        case let .packageNotFound(package): return "\(package.quoted) package not found"
        case let .repoNotFound(repo): return "Git repo not found at \(repo.quoted)"
        case let .cloneError(package): return "Couldn't clone \(package.gitPath) \(package.version)"
        case let .mintfileNotFound(path): return "\(path) not found"
        case let .invalidExecutable(executable): return "Couldn't find executable \(executable.quoted)"
        case let .missingExecutable(package): return "Executable product not found in \(package.namedVersion)"
        case let .packageResolveError(package): return "Failed to resolve \(package.namedVersion) with SPM"
        case let .packageBuildError(package): return "Failed to build \(package.namedVersion) with SPM"
        case let .packageReadError(error): return "Failed to read Package.swift file:\n\(error)"
        case let .packageNotInstalled(package): return "\(package.namedVersion) not installed"
        case let .revisionDuplicated(location, duplicatedParameters): return "\(location) has more than one revision specifier. (\(duplicatedParameters.sorted().joined(separator: ", ")))"
        case let .localPackageNeverHaveRevisionSpecifier(location, revisionSpecifiers): return "Local package \(location) cannot have revision specifier. (\(revisionSpecifiers.sorted().joined(separator: ", ")))"
        case let .locationSpecifierNotFound(yamlEntry): return "No location specifier found. package info: \(yamlEntry)"
        case let .locationDuplicated(yamlEntry): return "There is a package that has more than one location specifier. package info: \(yamlEntry)"
        }
    }

    public static func == (lhs: MintError, rhs: MintError) -> Bool {
        return lhs.description == rhs.description
    }

    public var errorDescription: String? {
        return description
    }
}
