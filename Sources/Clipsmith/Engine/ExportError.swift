import AVFoundation

enum ExportError: Error, LocalizedError {
    case nothingToExport
    case cannotCreateSession
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToExport: return localized("error.export.empty")
        case .cannotCreateSession: return localized("error.export.session")
        case .cancelled: return localized("error.export.cancelled")
        case .failed(let reason): return String(format: localized("error.export.failed"), reason)
        }
    }
}
