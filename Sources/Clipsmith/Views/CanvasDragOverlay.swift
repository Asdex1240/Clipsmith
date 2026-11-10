import SwiftUI

/// Transparent layer over the timeline preview that lets the user click and drag text and video on the canvas.
/// Red lines mark the canvas edges an object has reached or crossed.
struct CanvasDragOverlay: View {
    private enum Edge: Hashable { case left, right, top, bottom }
    private enum Axis: Hashable { case horizontal, vertical }

    private struct Target: Identifiable {
        let id: Clip.ID
        /// Where the object sits on the canvas, in render pixels.
        let frame: CGRect
        let isText: Bool
    }

    private struct DragStart {
        let offsetX: Double
        let offsetY: Double
        let frame: CGRect
    }

    private static let edgeTolerance = 1.0
    /// How close, in screen points, an edge must come to the canvas border before it sticks to it.
    private static let magnetDistance = 10.0
    private static let guideColor = Color.red
    private static let centerGuideColor = Color.cyan
    private static let guideWidth = 2.0
    private static let textRange = -0.25...1.25
    private static let offsetRange = -1.0...1.0

    let store: ProjectStore
    let renderSize: CGSize?
    let visualFrames: [Clip.ID: CGRect]

    @State private var dragStart: DragStart?
    @State private var reachedEdges: Set<Edge> = []
    /// Axes along which the dragged object is centered on the canvas.
    @State private var centeredAxes: Set<Axis> = []

    var body: some View {
        GeometryReader { proxy in
            if let renderSize, renderSize.width > 0, renderSize.height > 0 {
                let fitted = Self.fittedRect(of: renderSize, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    ForEach(targets(renderSize: renderSize)) { target in
                        handle(for: target, renderSize: renderSize, fitted: fitted)
                    }
                    guides(in: fitted)
                }
            }
        }
    }

    // MARK: Targets

    private func targets(renderSize: CGSize) -> [Target] {
        let time = store.playheadInSeconds
        func active(_ role: Track.Role) -> [Clip] {
            (store.project.track(withRole: role)?.clips ?? [])
                .filter { $0.startInSeconds <= time && time < $0.endInSeconds }
        }
        // Bottom to top, matching how the composition stacks them.
        let visuals = (active(.main) + active(.broll)).compactMap { clip -> Target? in
            guard let base = visualFrames[clip.id] else { return nil }
            let frame = base.offsetBy(dx: clip.offsetX * renderSize.width, dy: clip.offsetY * renderSize.height)
            return Target(id: clip.id, frame: frame, isText: false)
        }
        let texts = active(.text).compactMap { clip -> Target? in
            guard let layer = clip.textLayer else { return nil }
            let size = TextOverlayLayers.textSize(of: layer, renderSize: renderSize)
            let frame = CGRect(
                x: layer.positionX * renderSize.width - size.width / 2,
                y: layer.positionY * renderSize.height - size.height / 2,
                width: size.width, height: size.height
            )
            return Target(id: clip.id, frame: frame, isText: true)
        }
        return visuals + texts
    }

    // MARK: Views

    private func handle(for target: Target, renderSize: CGSize, fitted: CGRect) -> some View {
        let scale = fitted.width / renderSize.width
        let frame = CGRect(
            x: fitted.minX + target.frame.minX * scale,
            y: fitted.minY + target.frame.minY * scale,
            width: max(target.frame.width * scale, 24),
            height: max(target.frame.height * scale, 24)
        )
        let isSelected = store.selectedClipID == target.id
        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay {
                Rectangle().strokeBorder(
                    Color.accentColor.opacity(isSelected ? 0.9 : 0),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            }
            .frame(width: frame.width, height: frame.height)
            .contentShape(Rectangle())
            .position(x: frame.midX, y: frame.midY)
            .gesture(drag(target, renderSize: renderSize, scale: scale))
    }

    private func guides(in fitted: CGRect) -> some View {
        ZStack {
            if reachedEdges.contains(.left) { line(from: fitted.minX, fitted.minY, to: fitted.minX, fitted.maxY) }
            if reachedEdges.contains(.right) { line(from: fitted.maxX, fitted.minY, to: fitted.maxX, fitted.maxY) }
            if reachedEdges.contains(.top) { line(from: fitted.minX, fitted.minY, to: fitted.maxX, fitted.minY) }
            if reachedEdges.contains(.bottom) { line(from: fitted.minX, fitted.maxY, to: fitted.maxX, fitted.maxY) }
            if centeredAxes.contains(.horizontal) {
                line(from: fitted.midX, fitted.minY, to: fitted.midX, fitted.maxY, color: Self.centerGuideColor)
            }
            if centeredAxes.contains(.vertical) {
                line(from: fitted.minX, fitted.midY, to: fitted.maxX, fitted.midY, color: Self.centerGuideColor)
            }
        }
        .allowsHitTesting(false)
    }

    private func line(
        from x1: Double, _ y1: Double, to x2: Double, _ y2: Double, color: Color = Self.guideColor
    ) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
        }
        .stroke(color, lineWidth: Self.guideWidth)
    }

    // MARK: Dragging

    private func drag(_ target: Target, renderSize: CGSize, scale: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard scale > 0 else { return }
                guard let clip = store.project.clip(withID: target.id) else { return }
                if dragStart == nil {
                    dragStart = DragStart(
                        offsetX: target.isText ? clip.textLayer?.positionX ?? 0 : clip.offsetX,
                        offsetY: target.isText ? clip.textLayer?.positionY ?? 0 : clip.offsetY,
                        frame: target.frame
                    )
                    store.selectClip(target.id)
                }
                guard let start = dragStart else { return }
                let raw = CGSize(width: value.translation.width / scale, height: value.translation.height / scale)
                let delta = magnetized(raw, from: start.frame, canvas: renderSize, reach: Self.magnetDistance / scale)
                let x = start.offsetX + delta.width / renderSize.width
                let y = start.offsetY + delta.height / renderSize.height
                if target.isText {
                    store.updateTextLayer(of: target.id, field: "canvas-drag") {
                        $0.positionX = min(max(x, Self.textRange.lowerBound), Self.textRange.upperBound)
                        $0.positionY = min(max(y, Self.textRange.lowerBound), Self.textRange.upperBound)
                    }
                } else {
                    store.setOffset(
                        of: target.id,
                        x: min(max(x, Self.offsetRange.lowerBound), Self.offsetRange.upperBound),
                        y: min(max(y, Self.offsetRange.lowerBound), Self.offsetRange.upperBound)
                    )
                }
                let placed = start.frame.offsetBy(dx: delta.width, dy: delta.height)
                reachedEdges = edges(of: placed, moving: raw, in: renderSize)
                centeredAxes = centeredAxes(of: placed, in: renderSize)
            }
            .onEnded { _ in
                dragStart = nil
                reachedEdges = []
                centeredAxes = []
            }
    }

    /// Pulls the dragged frame onto a canvas border when one of its edges comes within `reach`.
    private func magnetized(_ delta: CGSize, from frame: CGRect, canvas: CGSize, reach: Double) -> CGSize {
        let moved = frame.offsetBy(dx: delta.width, dy: delta.height)
        return CGSize(
            width: delta.width + Self.pull(low: moved.minX, high: moved.maxX, limit: canvas.width, reach: reach),
            height: delta.height + Self.pull(low: moved.minY, high: moved.maxY, limit: canvas.height, reach: reach)
        )
    }

    /// The shift that puts the nearest of the two edges on the border, or the middle on the canvas center,
    /// or zero when none is close.
    private static func pull(low: Double, high: Double, limit: Double, reach: Double) -> Double {
        let candidates = [-low, limit - high, limit / 2 - (low + high) / 2]
        let nearest = candidates.min { abs($0) < abs($1) } ?? 0
        return abs(nearest) <= reach ? nearest : 0
    }

    private func centeredAxes(of frame: CGRect, in canvas: CGSize) -> Set<Axis> {
        var result: Set<Axis> = []
        if abs(frame.midX - canvas.width / 2) <= Self.edgeTolerance { result.insert(.horizontal) }
        if abs(frame.midY - canvas.height / 2) <= Self.edgeTolerance { result.insert(.vertical) }
        return result
    }

    /// Canvas edges the object touches or crosses, counting only the sides it is being pushed towards.
    private func edges(of frame: CGRect, moving delta: CGSize, in canvas: CGSize) -> Set<Edge> {
        let tolerance = Self.edgeTolerance
        var result: Set<Edge> = []
        if delta.width < 0, frame.minX <= tolerance { result.insert(.left) }
        if delta.width > 0, frame.maxX >= canvas.width - tolerance { result.insert(.right) }
        if delta.height < 0, frame.minY <= tolerance { result.insert(.top) }
        if delta.height > 0, frame.maxY >= canvas.height - tolerance { result.insert(.bottom) }
        return result
    }

    private static func fittedRect(of content: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / content.width, container.height / content.height)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2, y: (container.height - size.height) / 2,
            width: size.width, height: size.height
        )
    }
}
