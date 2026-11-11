import Foundation

struct ExportSettings: Equatable {
    static let supportedFrameRates = [24, 30, 60]

    var resolution: ExportResolution
    var codec: VideoCodec
    var framesPerSecond: Int
}
