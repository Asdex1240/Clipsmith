import AVFoundation

struct RenderLayer {
    let trackID: CMPersistentTrackID
    let clip: Clip
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let renderSize: CGSize
    var blend: LayerBlend?

    func blending(_ blend: LayerBlend) -> RenderLayer {
        var copy = self
        copy.blend = blend
        return copy
    }

    var needsAnimation: Bool { clip.needsAnimatedLayer || blend != nil }

    func transform(at time: TimeInterval) -> CGAffineTransform {
        let state = clip.visualState(atClipTime: time - clip.startInSeconds)
        let fitted = FitTransform.make(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            renderSize: renderSize,
            mode: clip.fitMode,
            offset: CGPoint(
                x: state.offsetX * renderSize.width, y: state.offsetY * renderSize.height),
            scale: state.scale,
            rotationInDegrees: state.rotationInDegrees
        )
        guard let blend else { return fitted }
        return fitted.concatenating(
            CGAffineTransform(translationX: blend.shift(at: time) * renderSize.width, y: 0))
    }

    func opacity(at time: TimeInterval) -> Double {
        clip.visualState(atClipTime: time - clip.startInSeconds).opacity
            * (blend?.opacity(at: time) ?? 1)
    }
}
