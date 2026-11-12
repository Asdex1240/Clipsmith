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
}
