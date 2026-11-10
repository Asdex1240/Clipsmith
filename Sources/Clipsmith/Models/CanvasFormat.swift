import Foundation

enum CanvasFormat: String, Codable, CaseIterable, Identifiable {
    case landscape, portrait

    var id: String { rawValue }

    var renderSize: CGSize {
        switch self {
        case .landscape: return CGSize(width: 1920, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1920)
        }
    }
}
