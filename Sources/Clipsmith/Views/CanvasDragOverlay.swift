import SwiftUI

/// Transparent layer over the timeline preview that lets the user move, scale and rotate text and video on the canvas.
/// Red lines mark the canvas edges an object has reached or crossed; cyan lines mark its center.
struct CanvasDragOverlay: View {
    private enum Edge: Hashable { case left, right, top, bottom }
    private enum Axis: Hashable { case horizontal, vertical }

    private struct Target: Identifiable {
        let id: Clip.ID
        let isText: Bool
        /// Center of the object on the canvas, in render pixels.
        let center: CGPoint
        /// Size before rotation, in render pixels.
        let size: CGSize
        let rotationInDegrees: Double

        /// Axis-aligned box around the rotated object, in render pixels.
        var bounds: CGRect {
            let radians = rotationInDegrees * .pi / 180
            let cosine = abs(cos(radians)), sine = abs(sin(radians))
            let width = size.width * cosine + size.height * sine
            let height = size.width * sine + size.height * cosine
            return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        }
    }

    /// What the object looked like when the gesture began.
    private struct Session {
        let offsetX: Double
        let offsetY: Double
        let scale: Double
        let fontSize: Double
        let rotationInDegrees: Double
        let bounds: CGRect
    }

    private static let space = "canvas"
    private static let edgeTolerance = 1.0
    /// How close, in screen points, an edge or the center must come to the canvas border or center to stick to it.
    private static let magnetDistance = 10.0
    private static let angleSnapStep = 45.0
    private static let angleSnapTolerance = 4.0
    private static let guideColor = Color.red
    private static let centerGuideColor = Color.cyan
    private static let guideWidth = 2.0
    private static let textRange = -0.25...1.25
    private static let offsetRange = -1.0...1.0
    private static let fontSizeRange = 20.0...240.0
    private static let minimumHandleSide = 24.0
    private static let cornerSize = 10.0
    private static let rotationStem = 26.0
    private static let rotationKnob = 12.0

    let store: ProjectStore
    let renderSize: CGSize?
    let visualFrames: [Clip.ID: CGRect]

    @State private var session: Session?
    @State private var reachedEdges: Set<Edge> = []
    @State private var centeredAxes: Set<Axis> = []

    var body: some View {
        GeometryReader { proxy in
            if let renderSize, renderSize.width > 0, renderSize.height > 0 {
                let fitted = Self.fittedRect(of: renderSize, in: proxy.size)
                let scale = fitted.width / renderSize.width
                ZStack(alignment: .topLeading) {
                    let all = targets(renderSize: renderSize)
                    ForEach(all) { target in
                        hitArea(of: target, renderSize: renderSize, fitted: fitted, scale: scale)
                    }
                    if let selected = all.first(where: { $0.id == store.selectedClipID }) {
                        controls(for: selected, renderSize: renderSize, fitted: fitted, scale: scale)
                    }
                    guides(in: fitted)
                }
                .coordinateSpace(name: Self.space)
            }
        }
    }

    // MARK: Targets

    private func targets(renderSize: CGSize) -> [Target] {
        let time = store.playheadInSeconds
        func active(_ tracks: [Track]) -> [Clip] {
            tracks.flatMap(\.clips).filter { $0.startInSeconds <= time && time < $0.endInSeconds }
        }
        // Bottom to top, matching how the composition stacks them.
        let visuals = active(store.project.videoTracksTopFirst.reversed()).map { $0.presented(atTimelineTime: time) }.compactMap { clip -> Target? in
            guard let base = visualFrames[clip.id] else { return nil }
            return Target(
                id: clip.id, isText: false,
                center: CGPoint(
                    x: base.midX + clip.offsetX * renderSize.width,
                    y: base.midY + clip.offsetY * renderSize.height
                ),
                size: CGSize(width: base.width * clip.scale, height: base.height * clip.scale),
                rotationInDegrees: clip.rotationInDegrees
            )
        }
        let texts = active(store.project.tracks(withRole: .text)).compactMap { clip -> Target? in
            guard let layer = clip.textLayer else { return nil }
            return Target(
                id: clip.id, isText: true,
                center: CGPoint(x: layer.positionX * renderSize.width, y: layer.positionY * renderSize.height),
                size: TextOverlayLayers.textSize(of: layer, renderSize: renderSize),
                rotationInDegrees: layer.rotationInDegrees
            )
        }
        return visuals + texts
    }

    // MARK: Views

    private func screenCenter(of target: Target, fitted: CGRect, scale: Double) -> CGPoint {
        CGPoint(x: fitted.minX + target.center.x * scale, y: fitted.minY + target.center.y * scale)
    }

    private func hitArea(of target: Target, renderSize: CGSize, fitted: CGRect, scale: Double) -> some View {
        let center = screenCenter(of: target, fitted: fitted, scale: scale)
        let isSelected = store.selectedClipID == target.id
        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay {
                Rectangle().strokeBorder(
                    Color.accentColor.opacity(isSelected ? 0.9 : 0),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            }
            .frame(
                width: max(target.size.width * scale, Self.minimumHandleSide),
                height: max(target.size.height * scale, Self.minimumHandleSide)
            )
            .rotationEffect(.degrees(target.rotationInDegrees))
            .contentShape(Rectangle())
            .position(center)
            .gesture(move(target, renderSize: renderSize, scale: scale))
    }

    /// Corner handles to resize and a knob above the top edge to rotate, shown for the selected object.
    private func controls(for target: Target, renderSize: CGSize, fitted: CGRect, scale: Double) -> some View {
        let center = screenCenter(of: target, fitted: fitted, scale: scale)
        let halfWidth = max(target.size.width * scale, Self.minimumHandleSide) / 2
        let halfHeight = max(target.size.height * scale, Self.minimumHandleSide) / 2
        let radians = target.rotationInDegrees * .pi / 180
        func rotated(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(
                x: center.x + x * cos(radians) - y * sin(radians),
                y: center.y + x * sin(radians) + y * cos(radians)
            )
        }
        let corners = [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]
        let knob = rotated(0, -halfHeight - Self.rotationStem)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: rotated(0, -halfHeight))
                path.addLine(to: knob)
            }
            .stroke(Color.accentColor, lineWidth: 1)
            ForEach(corners.indices, id: \.self) { index in
                let corner = corners[index]
                Rectangle()
                    .fill(.white)
                    .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
                    .frame(width: Self.cornerSize, height: Self.cornerSize)
                    .position(rotated(corner.0 * halfWidth, corner.1 * halfHeight))
                    .gesture(resize(target, center: center))
            }
            Circle()
                .fill(.white)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                .frame(width: Self.rotationKnob, height: Self.rotationKnob)
                .position(knob)
                .gesture(rotate(target, center: center))
        }
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

    // MARK: Gestures

    private func beginSession(for target: Target) -> Session? {
        if let session { return session }
        guard let clip = store.project.clip(withID: target.id)?.presented(atTimelineTime: store.playheadInSeconds) else { return nil }
        store.selectClip(target.id)
        let started = Session(
            offsetX: target.isText ? clip.textLayer?.positionX ?? 0 : clip.offsetX,
            offsetY: target.isText ? clip.textLayer?.positionY ?? 0 : clip.offsetY,
            scale: clip.scale,
            fontSize: clip.textLayer?.fontSize ?? 0,
            rotationInDegrees: target.rotationInDegrees,
            bounds: target.bounds
        )
        session = started
        return started
    }

    private func endSession() {
        session = nil
        reachedEdges = []
        centeredAxes = []
    }

    private func move(_ target: Target, renderSize: CGSize, scale: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard scale > 0, let start = beginSession(for: target) else { return }
                let raw = CGSize(
                    width: (value.location.x - value.startLocation.x) / scale,
                    height: (value.location.y - value.startLocation.y) / scale
                )
                let delta = magnetized(raw, from: start.bounds, canvas: renderSize, reach: Self.magnetDistance / scale)
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
                let placed = start.bounds.offsetBy(dx: delta.width, dy: delta.height)
                reachedEdges = edges(of: placed, moving: raw, in: renderSize)
                centeredAxes = centeredAxes(of: placed, in: renderSize)
            }
            .onEnded { _ in endSession() }
    }

    /// Dragging a corner scales the object by how much farther (or closer) the pointer is from its center.
    private func resize(_ target: Target, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard let start = beginSession(for: target) else { return }
                let startDistance = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
                let distance = hypot(value.location.x - center.x, value.location.y - center.y)
                guard startDistance > 0 else { return }
                let ratio = distance / startDistance
                if target.isText {
                    let size = min(max(start.fontSize * ratio, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
                    store.updateTextLayer(of: target.id, field: "canvas-scale") { $0.fontSize = size }
                } else {
                    store.setTransform(
                        of: target.id, scale: start.scale * ratio, rotationInDegrees: start.rotationInDegrees
                    )
                }
            }
            .onEnded { _ in endSession() }
    }

    /// Dragging the knob turns the object around its center, sticking to multiples of 45°.
    private func rotate(_ target: Target, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard let start = beginSession(for: target) else { return }
                let startAngle = atan2(value.startLocation.y - center.y, value.startLocation.x - center.x)
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                let degrees = Self.snappedAngle(start.rotationInDegrees + (angle - startAngle) * 180 / .pi)
                if target.isText {
                    store.updateTextLayer(of: target.id, field: "canvas-rotate") { $0.rotationInDegrees = degrees }
                } else {
                    store.setTransform(of: target.id, scale: start.scale, rotationInDegrees: degrees)
                }
            }
            .onEnded { _ in endSession() }
    }

    private static func snappedAngle(_ degrees: Double) -> Double {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)
        if normalized > 180 { normalized -= 360 }
        if normalized < -180 { normalized += 360 }
        let nearest = (normalized / angleSnapStep).rounded() * angleSnapStep
        return abs(normalized - nearest) <= angleSnapTolerance ? nearest : normalized
    }

    // MARK: Magnet and guides

    /// Pulls the dragged box onto a canvas border or center when one of its edges or its middle comes within `reach`.
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

    private func centeredAxes(of frame: CGRect, in canvas: CGSize) -> Set<Axis> {
        var result: Set<Axis> = []
        if abs(frame.midX - canvas.width / 2) <= Self.edgeTolerance { result.insert(.horizontal) }
        if abs(frame.midY - canvas.height / 2) <= Self.edgeTolerance { result.insert(.vertical) }
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
