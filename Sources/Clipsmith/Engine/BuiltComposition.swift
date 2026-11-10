import AVFoundation

struct BuiltComposition {
    let composition: AVMutableComposition
    let videoComposition: AVVideoComposition?
    let skippedClipIDs: [Clip.ID]

    var durationInSeconds: TimeInterval {
        composition.duration.seconds
    }

    func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        return item
    }
}
