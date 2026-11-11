import Foundation

enum ProjectFileError: Error, LocalizedError {
    case corrupted
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .corrupted:
            return localized("error.file.corrupted")
        case .unsupportedVersion(let version):
            return String(format: localized("error.file.unsupportedVersion"), version)
        }
    }
}
