import Foundation

enum VideoCodec: String, Codable, CaseIterable, Identifiable {
    case h264, hevc

    var id: String { rawValue }
}

enum ExportResolution: String, Codable, CaseIterable, Identifiable {
    case hd1080, uhd4K

    var id: String { rawValue }

    func renderSize(for canvas: CanvasFormat) -> CGSize {
        let landscape = landscapeSize
        switch canvas {
        case .landscape: return landscape
        case .portrait: return CGSize(width: landscape.height, height: landscape.width)
        }
    }

    private var landscapeSize: CGSize {
        switch self {
        case .hd1080: return CGSize(width: 1920, height: 1080)
        case .uhd4K: return CGSize(width: 3840, height: 2160)
        }
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
        allCases.first { $0.settings == settings && $0.canvas == canvas }
    }
}
