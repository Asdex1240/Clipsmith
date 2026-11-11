import CoreGraphics
import Foundation

enum CanvasEdge: Hashable { case left, right, top, bottom }
enum CanvasAxis: Hashable { case horizontal, vertical }

enum CanvasGeometry {
    static let edgeTolerance = 1.0
    static let angleSnapStep = 45.0
    static let angleSnapTolerance = 4.0
    private static let fullTurnInDegrees = 360.0
    private static let halfTurnInDegrees = 180.0

    static func snappedAngle(_ degrees: Double) -> Double {
        var normalized = degrees.truncatingRemainder(dividingBy: fullTurnInDegrees)
        if normalized > halfTurnInDegrees { normalized -= fullTurnInDegrees }
        if normalized < -halfTurnInDegrees { normalized += fullTurnInDegrees }
        let nearest = (normalized / angleSnapStep).rounded() * angleSnapStep
        return abs(normalized - nearest) <= angleSnapTolerance ? nearest : normalized
    }

    static func magnetized(_ delta: CGSize, from frame: CGRect, canvas: CGSize, reach: Double) -> CGSize {
        let moved = frame.offsetBy(dx: delta.width, dy: delta.height)
        return CGSize(
            width: delta.width + pull(low: moved.minX, high: moved.maxX, limit: canvas.width, reach: reach),
            height: delta.height + pull(low: moved.minY, high: moved.maxY, limit: canvas.height, reach: reach)
        )
    }

    static func pull(low: Double, high: Double, limit: Double, reach: Double) -> Double {
        let candidates = [-low, limit - high, limit / 2 - (low + high) / 2]
        let nearest = candidates.min { abs($0) < abs($1) } ?? 0
        return abs(nearest) <= reach ? nearest : 0
    }

    static func edges(of frame: CGRect, moving delta: CGSize, in canvas: CGSize) -> Set<CanvasEdge> {
        var result: Set<CanvasEdge> = []
        if delta.width < 0, frame.minX <= edgeTolerance { result.insert(.left) }
        if delta.width > 0, frame.maxX >= canvas.width - edgeTolerance { result.insert(.right) }
        if delta.height < 0, frame.minY <= edgeTolerance { result.insert(.top) }
        if delta.height > 0, frame.maxY >= canvas.height - edgeTolerance { result.insert(.bottom) }
        return result
    }

    static func centeredAxes(of frame: CGRect, in canvas: CGSize) -> Set<CanvasAxis> {
        var result: Set<CanvasAxis> = []
        if abs(frame.midX - canvas.width / 2) <= edgeTolerance { result.insert(.horizontal) }
        if abs(frame.midY - canvas.height / 2) <= edgeTolerance { result.insert(.vertical) }
        return result
    }

    static func fittedRect(of content: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / content.width, container.height / content.height)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2, y: (container.height - size.height) / 2,
            width: size.width, height: size.height
        )
    }
}
