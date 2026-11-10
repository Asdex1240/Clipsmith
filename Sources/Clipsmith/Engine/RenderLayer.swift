import AVFoundation

/// How a transition changes one of the two layers it blends.
struct LayerBlend {
    let transition: PlannedTransition
    let isOutgoing: Bool

    func opacity(at time: TimeInterval) -> Double {
        let values = transition.kind.opacity(at: transition.progress(at: time))
        return isOutgoing ? values.outgoing : values.incoming
    }

    func shift(at time: TimeInterval) -> Double {
        let values = transition.kind.shift(at: transition.progress(at: time))
        return isOutgoing ? values.outgoing : values.incoming
    }

    var breakpoints: [TimeInterval] {
        transition.kind.breakpoints.map {
            transition.windowStart + $0 * (transition.windowEnd - transition.windowStart)
        }
    }
}

/// One visual clip as drawn on the canvas: where its frames come from and how its look changes over time.
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

    /// Maps the frame, in source pixels with a top-left origin, onto the canvas with a top-left origin.
    func transform(at time: TimeInterval) -> CGAffineTransform {
        let state = clip.visualState(atClipTime: time - clip.startInSeconds)
        let fitted = FitTransform.make(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            renderSize: renderSize,
            mode: clip.fitMode,
            offset: CGPoint(x: state.offsetX * renderSize.width, y: state.offsetY * renderSize.height),
            scale: state.scale,
            rotationInDegrees: state.rotationInDegrees
        )
        guard let blend else { return fitted }
        return fitted.concatenating(CGAffineTransform(translationX: blend.shift(at: time) * renderSize.width, y: 0))
    }

    func opacity(at time: TimeInterval) -> Double {
        clip.visualState(atClipTime: time - clip.startInSeconds).opacity * (blend?.opacity(at: time) ?? 1)
    }
}
