import Foundation

struct VisualState: Codable, Equatable {
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
    var timeInSeconds: TimeInterval
    var state: VisualState
    var easing = Easing.linear
}

extension Keyframe {
    private enum CodingKeys: String, CodingKey {
        case id, timeInSeconds, state, easing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timeInSeconds = try container.decode(TimeInterval.self, forKey: .timeInSeconds)
        state = try container.decode(VisualState.self, forKey: .state)
        easing = try container.decodeIfPresent(Easing.self, forKey: .easing) ?? .linear
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timeInSeconds, forKey: .timeInSeconds)
        try container.encode(state, forKey: .state)
        if !easing.isLinear { try container.encode(easing, forKey: .easing) }
    }
}

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
