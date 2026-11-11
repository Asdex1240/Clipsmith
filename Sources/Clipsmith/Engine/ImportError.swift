import AVFoundation
import ImageIO

enum ImportError: Error, LocalizedError {
    case unsupportedFormat(URL)
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let url):
            return String(format: localized("error.import.unsupported"), url.lastPathComponent)
        case .unreadable(let url):
            return String(format: localized("error.import.unreadable"), url.lastPathComponent)
        }
    }
}
