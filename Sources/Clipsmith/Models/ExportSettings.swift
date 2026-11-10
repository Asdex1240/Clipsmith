import Foundation

enum VideoCodec: String, Codable, CaseIterable, Identifiable {
    case h264, hevc

    var id: String { rawValue }
}

enum ExportResolution: String, Codable, CaseIterable, Identifiable {
    case hd720, hd1080, qhd1440, uhd4K, canvasSize

    var id: String { rawValue }

    /// Pixels of the shorter side of the output; nil exports at exactly the canvas size.
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

struct ExportSettings: Equatable {
    static let supportedFrameRates = [24, 30, 60]

    var resolution: ExportResolution
    var codec: VideoCodec
    var framesPerSecond: Int
}

enum ExportPreset: String, CaseIterable, Identifiable {
    case youtube1080, youtube1080x60, youtube4K, landscape720, vertical1080, instagramPost, square1080

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
        case .youtube1080x60: return ExportSettings(resolution: .hd1080, codec: .h264, framesPerSecond: 60)
        case .youtube4K: return ExportSettings(resolution: .uhd4K, codec: .hevc, framesPerSecond: 30)
        case .landscape720: return ExportSettings(resolution: .hd720, codec: .h264, framesPerSecond: 30)
        }
    }

    static func matching(settings: ExportSettings, canvas: CanvasFormat) -> ExportPreset? {
        allCases.first { $0.settings == settings && $0.canvas.aspectLabel == canvas.aspectLabel }
    }
}
