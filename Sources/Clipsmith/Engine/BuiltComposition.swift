import AVFoundation

struct BuiltComposition {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition?
    let audioMix: AVAudioMix?
    let textOverlay: TextOverlay?
    let skippedClipIDs: [Clip.ID]
    var visualFrames: [Clip.ID: CGRect] = [:]

    var durationInSeconds: TimeInterval {
        composition.duration.seconds
    }

    func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        item.audioTimePitchAlgorithm = .spectral
        return item
    }

    func attachTextOverlayForExport() {
        guard let videoComposition, let textOverlay, !textOverlay.isEmpty else { return }
        guard videoComposition.customVideoCompositorClass == nil else {
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
