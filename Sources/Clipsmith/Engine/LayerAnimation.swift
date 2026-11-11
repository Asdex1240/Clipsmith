import Foundation

enum LayerAnimation {
    private static let edgeToleranceInSeconds: TimeInterval = 1e-6
    private static let maximumDegreesPerStep = 10.0
    private static let maximumScaleChangePerStep = 0.1
    private static let maximumStepsPerSpan = 60
    private static let minimumStepsWhenEased = 12

    static func samplePoints(
        for clip: Clip, from start: TimeInterval, to end: TimeInterval, extraAnchors: [TimeInterval] = []
    ) -> [TimeInterval] {
        guard end > start else { return [start] }
        let anchors = (clip.keyframes.map { clip.startInSeconds + $0.timeInSeconds } + extraAnchors)
            .filter { $0 > start + edgeToleranceInSeconds && $0 < end - edgeToleranceInSeconds }
        let corners = ([start] + anchors + [end]).sorted()
        var points: [TimeInterval] = [start]
        for (from, to) in zip(corners, corners.dropFirst()) {
            let steps = stepCount(for: clip, from: from, to: to)
            for step in 1...steps {
                points.append(from + (to - from) * Double(step) / Double(steps))
            }
        }
        return points
    }

    private static func stepCount(for clip: Clip, from: TimeInterval, to: TimeInterval) -> Int {
        let a = clip.visualState(atClipTime: from - clip.startInSeconds)
        let b = clip.visualState(atClipTime: to - clip.startInSeconds)
        let turnSteps = abs(b.rotationInDegrees - a.rotationInDegrees) / maximumDegreesPerStep
        let zoomSteps = abs(b.scale - a.scale) / max(min(a.scale, b.scale), 0.01) / maximumScaleChangePerStep
        var easedSteps = 1.0
        if clip.eased(from: from - clip.startInSeconds) { easedSteps = Double(minimumStepsWhenEased) }
        return min(max(Int(ceil(max(turnSteps, zoomSteps, easedSteps))), 1), maximumStepsPerSpan)
    }
}
