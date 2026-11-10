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
        // Sped-up or slowed-down audio keeps its pitch.
        item.audioTimePitchAlgorithm = .spectral
        return item
    }

    func attachTextOverlayForExport() {
        guard let videoComposition, let textOverlay, !textOverlay.isEmpty else { return }
        guard videoComposition.customVideoCompositorClass == nil else {
            // Core Animation cannot post-process frames from a custom compositor, so it draws the text itself.
            let sprites = TextOverlayLayers.makeSprites(for: textOverlay)
            videoComposition.instructions = videoComposition.instructions.map { instruction in
                guard let effects = instruction as? EffectsInstruction else { return instruction }
                return EffectsInstruction(timeRange: effects.timeRange, layers: effects.layers, texts: sprites)
            }
            return
        }
        TextOverlayLayers.attach(textOverlay, to: videoComposition)
    }
}
