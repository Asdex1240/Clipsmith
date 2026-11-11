import Foundation

enum ExportPreset: String, CaseIterable, Identifiable {
    case youtube1080, youtube1080x60, youtube4K, landscape720, vertical1080, instagramPost,
        square1080

    var id: String { rawValue }

    var canvas: CanvasFormat {
        switch self {
        case .vertical1080: return .portrait
        case .instagramPost: return .portrait4x5
        case .square1080: return .square
        case .youtube1080, .youtube1080x60, .youtube4K, .landscape720: return .landscape
        }
    }

    var settings: ExportSettings {
        switch self {
        case .youtube1080, .vertical1080, .instagramPost, .square1080:
            return ExportSettings(resolution: .hd1080, codec: .h264, framesPerSecond: 30)
        case .youtube1080x60:
            return ExportSettings(resolution: .hd1080, codec: .h264, framesPerSecond: 60)
        case .youtube4K:
            return ExportSettings(resolution: .uhd4K, codec: .hevc, framesPerSecond: 30)
        case .landscape720:
            return ExportSettings(resolution: .hd720, codec: .h264, framesPerSecond: 30)
        }
    }

    static func matching(settings: ExportSettings, canvas: CanvasFormat) -> ExportPreset? {
        allCases.first { $0.settings == settings && $0.canvas.aspectLabel == canvas.aspectLabel }
    }
}
