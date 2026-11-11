import Foundation

struct TextAnimation: Codable, Equatable {
    static let durationRange = 0.1...2.0
    static let defaultDuration = 0.4
    private static let slideDistance = 0.05
    private static let popStartScale = 0.7

    var inKind = TextAnimationKind.none
    var outKind = TextAnimationKind.none
    var durationInSeconds = TextAnimation.defaultDuration

    var isNone: Bool { inKind == .none && outKind == .none }

    init(
        inKind: TextAnimationKind = .none, outKind: TextAnimationKind = .none,
        durationInSeconds: TimeInterval = defaultDuration
    ) {
        self.inKind = inKind
        self.outKind = outKind
        self.durationInSeconds = durationInSeconds
    }

    static func both(_ kind: TextAnimationKind) -> TextAnimation {
        TextAnimation(inKind: kind, outKind: kind)
    }

    func state(atClipTime time: TimeInterval, clipDuration: TimeInterval) -> TextAnimationState {
        guard !isNone, clipDuration > 0 else { return .identity }
        let window = min(durationInSeconds, clipDuration / 2)
        guard window > 0 else { return .identity }
        let arriving = Self.effect(of: inKind, shown: Easing.easeOut.apply(time / window))
        let leaving = Self.effect(
            of: outKind, shown: Easing.easeOut.apply((clipDuration - time) / window))
        return TextAnimationState(
            opacity: arriving.opacity * leaving.opacity,
            offsetY: arriving.offsetY + leaving.offsetY,
            scale: arriving.scale * leaving.scale
        )
    }

    func samplePoints(clipDuration: TimeInterval, framesPerSecond: Double = 30) -> [TimeInterval] {
        let window = min(durationInSeconds, clipDuration / 2)
        let step = 1 / framesPerSecond
        var times: Set<TimeInterval> = [0, clipDuration]
        if inKind != .none {
            var time = 0.0
            while time < window { times.insert(time); time += step }
            times.insert(window)
        }
        if outKind != .none {
            var time = clipDuration - window
            while time < clipDuration { times.insert(time); time += step }
            times.insert(clipDuration - window)
        }
        return times.sorted()
    }

    private static func effect(of kind: TextAnimationKind, shown: Double) -> TextAnimationState {
        switch kind {
        case .none: return .identity
        case .fade: return TextAnimationState(opacity: shown)
        case .slideUp:
            return TextAnimationState(opacity: shown, offsetY: (1 - shown) * slideDistance)
        case .slideDown:
            return TextAnimationState(opacity: shown, offsetY: -(1 - shown) * slideDistance)
        case .pop:
            return TextAnimationState(
                opacity: shown, scale: popStartScale + (1 - popStartScale) * shown)
        }
    }
}

extension TextAnimation {
    private enum CodingKeys: String, CodingKey {
        case inKind, outKind, durationInSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inKind = try container.decodeIfPresent(TextAnimationKind.self, forKey: .inKind) ?? .none
        outKind = try container.decodeIfPresent(TextAnimationKind.self, forKey: .outKind) ?? .none
        durationInSeconds =
            try container.decodeIfPresent(TimeInterval.self, forKey: .durationInSeconds)
            ?? Self.defaultDuration
    }
}
