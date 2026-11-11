import Foundation

enum KeyframeInterpolation {
    static func easing(at time: TimeInterval, in keyframes: [Keyframe]) -> Easing {
        guard let frame = keyframes.last(where: { $0.timeInSeconds <= time }),
            keyframes.contains(where: { $0.timeInSeconds > time })
        else { return .linear }
        return frame.easing
    }

    static func state(
        at time: TimeInterval, in keyframes: [Keyframe], fallback: VisualState
    ) -> VisualState {
        guard let first = keyframes.first, let last = keyframes.last else { return fallback }
        if time <= first.timeInSeconds { return first.state }
        if time >= last.timeInSeconds { return last.state }
        guard let nextIndex = keyframes.firstIndex(where: { $0.timeInSeconds > time }),
            nextIndex > 0
        else {
            return last.state
        }
        let previous = keyframes[nextIndex - 1]
        let next = keyframes[nextIndex]
        let span = next.timeInSeconds - previous.timeInSeconds
        guard span > 0 else { return next.state }
        let fraction = previous.easing.apply((time - previous.timeInSeconds) / span)
        return previous.state.interpolated(to: next.state, fraction: fraction)
    }
}
