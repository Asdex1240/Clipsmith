import Foundation

enum StabilizationPlanner {
    static let minimumSamples = 3

    static func plan(
        from motion: [MotionSample], strength: StabilizationStrength
    ) -> Stabilization? {
        guard motion.count >= minimumSamples else { return nil }
        let ordered = motion.sorted { $0.timeInSeconds < $1.timeInSeconds }
        let path = cumulativePath(of: ordered)
        let smoothed = smoothedPath(path, window: strength.smoothingWindowInSeconds)
        let corrections = zip(smoothed, path).map { smooth, raw in
            (dx: smooth.dx - raw.dx, dy: smooth.dy - raw.dy)
        }
        return Stabilization(
            points: clamped(corrections, times: path.map(\.timeInSeconds), strength: strength),
            zoom: zoom(for: corrections, strength: strength))
    }

    private static func cumulativePath(of motion: [MotionSample]) -> [StabilizationPoint] {
        var x = 0.0
        var y = 0.0
        return motion.map { sample in
            x += sample.dx
            y += sample.dy
            return StabilizationPoint(timeInSeconds: sample.timeInSeconds, dx: x, dy: y)
        }
    }

    private static func smoothedPath(
        _ path: [StabilizationPoint], window: TimeInterval
    ) -> [StabilizationPoint] {
        path.map { point in
            let neighbours = path.filter {
                abs($0.timeInSeconds - point.timeInSeconds) <= window / 2
            }
            let count = Double(neighbours.count)
            return StabilizationPoint(
                timeInSeconds: point.timeInSeconds,
                dx: neighbours.reduce(0) { $0 + $1.dx } / count,
                dy: neighbours.reduce(0) { $0 + $1.dy } / count)
        }
    }

    private static func zoom(
        for corrections: [(dx: Double, dy: Double)], strength: StabilizationStrength
    ) -> Double {
        let largest = corrections.map { max(abs($0.dx), abs($0.dy)) }.max() ?? 0
        return min(1 + 2 * largest, strength.maximumZoom)
    }

    private static func clamped(
        _ corrections: [(dx: Double, dy: Double)], times: [TimeInterval],
        strength: StabilizationStrength
    ) -> [StabilizationPoint] {
        let limit = (zoom(for: corrections, strength: strength) - 1) / 2
        return zip(times, corrections).map { time, correction in
            StabilizationPoint(
                timeInSeconds: time,
                dx: min(max(correction.dx, -limit), limit),
                dy: min(max(correction.dy, -limit), limit))
        }
    }
}
