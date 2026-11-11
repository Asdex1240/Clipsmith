import AVFoundation

struct LayerBlend {
    let transition: PlannedTransition
    let isOutgoing: Bool

    func opacity(at time: TimeInterval) -> Double {
        let values = transition.kind.opacity(at: transition.progress(at: time))
        return value(from: values)
    }

    func shift(at time: TimeInterval) -> Double {
        let values = transition.kind.shift(at: transition.progress(at: time))
        return value(from: values)
    }

    private func value(from values: (outgoing: Double, incoming: Double)) -> Double {
        if isOutgoing { return values.outgoing }
        return values.incoming
    }

    var breakpoints: [TimeInterval] {
        let span = transition.windowEnd - transition.windowStart
        let corners = transition.kind.breakpoints.map { transition.easing.time(forProgress: $0) }
        var samples: [Double] = []
        if !transition.easing.isLinear {
            samples = (1..<Self.samplesWhenEased).map { Double($0) / Double(Self.samplesWhenEased) }
        }
        return (corners + samples).map { transition.windowStart + $0 * span }
    }

    private static let samplesWhenEased = 12
}

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
