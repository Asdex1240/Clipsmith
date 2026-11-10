import Foundation

extension Clip {
    static let keyframeToleranceInSeconds: TimeInterval = 0.05
    static let opacityRange = 0.0...1.0

    var staticVisualState: VisualState {
        VisualState(offsetX: offsetX, offsetY: offsetY, scale: scale, rotationInDegrees: rotationInDegrees, opacity: opacity)
    }

    var isAnimated: Bool { !keyframes.isEmpty }

    /// True when the clip needs per-frame values instead of one fixed transform.
    var needsAnimatedLayer: Bool { isAnimated || opacity != 1 }

    func visualState(atClipTime time: TimeInterval) -> VisualState {
        KeyframeInterpolation.state(at: time, in: keyframes, fallback: staticVisualState)
    }

    /// The clip as it looks at a timeline time: its offset, size, turn and opacity are the animated ones.
    func presented(atTimelineTime time: TimeInterval) -> Clip {
        guard isAnimated else { return self }
        var clip = self
        let state = visualState(atClipTime: time - startInSeconds)
        clip.offsetX = state.offsetX
        clip.offsetY = state.offsetY
        clip.scale = state.scale
        clip.rotationInDegrees = state.rotationInDegrees
        clip.opacity = state.opacity
        return clip
    }

    /// Edits the look of the clip. Without keyframes it changes the fixed values; with keyframes it sets
    /// the keyframe at `timelineTime`, creating it if there is none there yet.
    func updatingVisual(at timelineTime: TimeInterval?, _ change: (inout VisualState) -> Void) -> Clip {
        if isAnimated, let timelineTime {
            return updatingKeyframe(atClipTime: timelineTime - startInSeconds, change)
        }
        var state = staticVisualState
        change(&state)
        var clip = self
        clip.apply(state.clamped())
        return clip
    }

    func addingKeyframe(atClipTime time: TimeInterval) -> Clip {
        updatingKeyframe(atClipTime: time) { _ in }
    }

    func removingKeyframe(_ id: Keyframe.ID) -> Clip {
        var clip = self
        clip.keyframes.removeAll { $0.id == id }
        return clip
    }

    func clearingKeyframes() -> Clip {
        var clip = self
        clip.keyframes = []
        return clip
    }

    private func updatingKeyframe(atClipTime proposed: TimeInterval, _ change: (inout VisualState) -> Void) -> Clip {
        let time = min(max(proposed, 0), durationInSeconds)
        var state = visualState(atClipTime: time)
        change(&state)
        state = state.clamped()
        var clip = self
        if let index = keyframes.firstIndex(where: { abs($0.timeInSeconds - time) <= Self.keyframeToleranceInSeconds }) {
            clip.keyframes[index].state = state
        } else {
            clip.keyframes.append(Keyframe(timeInSeconds: time, state: state))
            clip.keyframes.sort { $0.timeInSeconds < $1.timeInSeconds }
        }
        return clip
    }

    private mutating func apply(_ state: VisualState) {
        offsetX = state.offsetX
        offsetY = state.offsetY
        scale = state.scale
        rotationInDegrees = state.rotationInDegrees
        opacity = state.opacity
    }

    /// Keyframes follow the picture when the start of the clip moves by `delta` seconds.
    func shiftingKeyframes(by delta: TimeInterval) -> [Keyframe] {
        keyframes.map { frame in
            var shifted = frame
            shifted.timeInSeconds += delta
            return shifted
        }
    }
}

extension VisualState {
    func clamped() -> VisualState {
        var state = self
        state.scale = min(max(scale, Clip.scaleRange.lowerBound), Clip.scaleRange.upperBound)
        state.opacity = min(max(opacity, Clip.opacityRange.lowerBound), Clip.opacityRange.upperBound)
        return state
    }
}
