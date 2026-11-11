import AVFoundation
import CoreImage

final class EffectsInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable
{
    let timeRange: CMTimeRange
    let layers: [RenderLayer]
    let texts: [TextSprite]
    let enablePostProcessing = false
    let containsTweening = true
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let requiredSourceTrackIDs: [NSValue]?

    init(timeRange: CMTimeRange, layers: [RenderLayer], texts: [TextSprite] = []) {
        self.timeRange = timeRange
        self.layers = layers
        self.texts = texts
        var seen = Set<CMPersistentTrackID>()
        let newTrackIDs = layers.map(\.trackID).filter { seen.insert($0).inserted }
        requiredSourceTrackIDs = newTrackIDs.map { NSNumber(value: $0) }
    }
}
