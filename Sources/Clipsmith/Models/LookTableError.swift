import Foundation

enum LookTableError: Error, LocalizedError, Equatable {
    case missingSize
    case wrongEntryCount
    case unreadable

    var errorDescription: String? {
        switch self {
        case .missingSize: return localized("error.lut.missingSize")
        case .wrongEntryCount: return localized("error.lut.wrongEntryCount")
        case .unreadable: return localized("error.lut.unreadable")
        }
    }
}
