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
