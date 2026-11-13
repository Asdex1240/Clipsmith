import Foundation

struct FramingCurve: Equatable {
    static let subdivisionsPerEasedSegment = 6

    let staticOffsetX: Double
    let keyframes: [FramingKeyframe]

    init(staticOffsetX: Double, keyframes: [FramingKeyframe]) {
        self.staticOffsetX = staticOffsetX
        self.keyframes = keyframes.sorted { $0.timeInSeconds < $1.timeInSeconds }
    }

    var isAnimated: Bool { !keyframes.isEmpty }

    func offsetX(at time: TimeInterval) -> Double {
        guard let first = keyframes.first, let last = keyframes.last else { return staticOffsetX }
        guard time > first.timeInSeconds else { return first.offsetX }
        guard time < last.timeInSeconds else { return last.offsetX }
        guard let next = keyframes.firstIndex(where: { $0.timeInSeconds > time }) else {
            return last.offsetX
        }
        let from = keyframes[next - 1]
        let to = keyframes[next]
        let span = to.timeInSeconds - from.timeInSeconds
        guard span > 0 else { return to.offsetX }
        let progress = from.easing.apply((time - from.timeInSeconds) / span)
        return from.offsetX + (to.offsetX - from.offsetX) * progress
    }

    func sampleTimes(from start: TimeInterval, to end: TimeInterval) -> [TimeInterval] {
        guard isAnimated, end > start else { return [] }
        var times: Set<TimeInterval> = []
        for index in keyframes.indices {
            times.insert(keyframes[index].timeInSeconds)
            guard index + 1 < keyframes.count, !keyframes[index].easing.isLinear else { continue }
            let from = keyframes[index].timeInSeconds
            let span = keyframes[index + 1].timeInSeconds - from
            for step in 1..<Self.subdivisionsPerEasedSegment {
                times.insert(from + span * Double(step) / Double(Self.subdivisionsPerEasedSegment))
            }
        }
        return times.filter { $0 > start && $0 < end }.sorted()
    }
}
