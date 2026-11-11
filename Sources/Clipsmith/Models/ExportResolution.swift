import Foundation

enum ExportResolution: String, Codable, CaseIterable, Identifiable {
    case hd720, hd1080, qhd1440, uhd4K, canvasSize

    var id: String { rawValue }

    var shortSide: Int? {
        switch self {
        case .hd720: return 720
        case .hd1080: return 1080
        case .qhd1440: return 1440
        case .uhd4K: return 2160
        case .canvasSize: return nil
        }
    }

    func renderSize(for canvas: CanvasFormat) -> CGSize {
        guard let shortSide else { return canvas.renderSize }
        return canvas.scaled(toShortSide: shortSide).renderSize
    }
}
