import Foundation

/// The look of a visual clip at one moment: where it sits, how big it is, how it is turned and how opaque it is.
struct VisualState: Codable, Equatable {
    /// Shift on the canvas as a fraction of its width and height.
    var offsetX = 0.0
    var offsetY = 0.0
    var scale = 1.0
    var rotationInDegrees = 0.0
    var opacity = 1.0

    func interpolated(to other: VisualState, fraction: Double) -> VisualState {
        func mix(_ from: Double, _ to: Double) -> Double { from + (to - from) * fraction }
        return VisualState(
            offsetX: mix(offsetX, other.offsetX),
            offsetY: mix(offsetY, other.offsetY),
            scale: mix(scale, other.scale),
            rotationInDegrees: mix(rotationInDegrees, other.rotationInDegrees),
            opacity: mix(opacity, other.opacity)
        )
    }
}

struct Keyframe: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Seconds after the start of the clip on the timeline.
    var timeInSeconds: TimeInterval
    var state: VisualState
}

enum KeyframeInterpolation {
    /// The state at `time` given keyframes sorted by time: it holds the first and last values outside them
    /// and moves in a straight line between neighbours.
    static func state(at time: TimeInterval, in keyframes: [Keyframe], fallback: VisualState) -> VisualState {
        guard let first = keyframes.first, let last = keyframes.last else { return fallback }
        if time <= first.timeInSeconds { return first.state }
        if time >= last.timeInSeconds { return last.state }
        guard let nextIndex = keyframes.firstIndex(where: { $0.timeInSeconds > time }), nextIndex > 0 else {
            return last.state
        }
        let previous = keyframes[nextIndex - 1]
        let next = keyframes[nextIndex]
        let span = next.timeInSeconds - previous.timeInSeconds
        guard span > 0 else { return next.state }
        return previous.state.interpolated(to: next.state, fraction: (time - previous.timeInSeconds) / span)
    }
}
