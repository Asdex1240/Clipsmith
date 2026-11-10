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
    case youtube1080, youtube4K, vertical1080

    var id: String { rawValue }

    var canvas: CanvasFormat {
        self == .vertical1080 ? .portrait : .landscape
    }

    var settings: ExportSettings {
        switch self {
        case .youtube1080: return ExportSettings(resolution: .hd1080, codec: .h264, framesPerSecond: 30)
        case .youtube4K: return ExportSettings(resolution: .uhd4K, codec: .hevc, framesPerSecond: 30)
        case .vertical1080: return ExportSettings(resolution: .hd1080, codec: .h264, framesPerSecond: 30)
        }
    }

    static func matching(settings: ExportSettings, canvas: CanvasFormat) -> ExportPreset? {
        allCases.first { $0.settings == settings && $0.canvas.aspectLabel == canvas.aspectLabel }
    }
}
