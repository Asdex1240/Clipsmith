import Foundation

protocol StabilizationAnalyzing {
    func motion(
        in url: URL, sourceRange: ClosedRange<TimeInterval>,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [MotionSample]?
}
