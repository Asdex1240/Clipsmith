import Foundation

enum FaceFraming {
    static func offsetX(
        faceCenters: [Double], sourceAspect: Double, canvasAspect: Double
    ) -> Double? {
        guard !faceCenters.isEmpty, sourceAspect > 0, canvasAspect > 0 else { return nil }
        let ratio = sourceAspect / canvasAspect
        guard ratio > 1 else { return 0 }
        let sorted = faceCenters.sorted()
        let median = sorted[sorted.count / 2]
        let wanted = -(median - 0.5) * ratio
        let limit = (ratio - 1) / 2
        return Highlight.clampedFraming(min(max(wanted, -limit), limit))
    }

    static let minimumTrackedKeyframes = 2
    private static let smoothingWeights = [0.25, 0.5, 0.25]

    static func keyframes(
        faceCenters: [Double], at times: [TimeInterval], sourceAspect: Double,
        canvasAspect: Double
    ) -> [FramingKeyframe]? {
        guard faceCenters.count == times.count, faceCenters.count >= minimumTrackedKeyframes,
            sourceAspect > 0, canvasAspect > 0
        else { return nil }
        let ratio = sourceAspect / canvasAspect
        guard ratio > 1 else { return nil }
        let limit = (ratio - 1) / 2
        let raw = faceCenters.map { min(max(-($0 - 0.5) * ratio, -limit), limit) }
        let smoothed = smoothed(raw)
        return zip(times, smoothed).map { FramingKeyframe(timeInSeconds: $0, offsetX: $1) }
    }

    private static func smoothed(_ values: [Double]) -> [Double] {
        values.indices.map { index in
            let before = values[max(index - 1, 0)]
            let after = values[min(index + 1, values.count - 1)]
            return before * smoothingWeights[0] + values[index] * smoothingWeights[1]
                + after * smoothingWeights[2]
        }
    }
}
