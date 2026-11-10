import AVFoundation

struct BuiltComposition {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition?
    let audioMix: AVAudioMix?
    let textOverlay: TextOverlay?
    let skippedClipIDs: [Clip.ID]
    /// Where each visual clip sits on the canvas before its offset is applied, in render pixels.
    var visualFrames: [Clip.ID: CGRect] = [:]

    var durationInSeconds: TimeInterval {
        composition.duration.seconds
    }

    func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        return item
    }

    func attachTextOverlayForExport() {
        guard let videoComposition, let textOverlay, !textOverlay.isEmpty else { return }
        TextOverlayLayers.attach(textOverlay, to: videoComposition)
    }
}
