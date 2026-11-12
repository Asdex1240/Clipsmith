import SwiftUI

struct CanvasDragOverlay: View {
    private struct Session {
        let offsetX: Double
        let offsetY: Double
        let scale: Double
        let fontSize: Double
        let rotationInDegrees: Double
        let bounds: CGRect
    }

    private static let space = "canvas"
    private static let magnetDistance = 10.0
    private static let guideColor = Palette.guideEdge
    private static let centerGuideColor = Palette.guideCenter
    private static let guideWidth = Design.Stroke.emphasized
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
    @State private var reachedEdges: Set<CanvasEdge> = []
    @State private var centeredAxes: Set<CanvasAxis> = []

    private static let selectedOutlineOpacity = Design.Opacity.selectedOutline

    private func outlineOpacity(of target: CanvasTarget) -> Double {
        if store.selectedClipID == target.id { return Self.selectedOutlineOpacity }
        return 0
    }

    private func dragStart(of target: CanvasTarget, clip: Clip) -> (x: Double, y: Double) {
        guard target.isText else { return (clip.offsetX, clip.offsetY) }
        return (clip.textLayer?.positionX ?? 0, clip.textLayer?.positionY ?? 0)
    }

    var body: some View {
        GeometryReader { proxy in
            if let renderSize, renderSize.width > 0, renderSize.height > 0 {
                let fitted = CanvasGeometry.fittedRect(of: renderSize, in: proxy.size)
                let scale = fitted.width / renderSize.width
                ZStack(alignment: .topLeading) {
                    let all = targets(renderSize: renderSize)
                    ForEach(all) { target in
                        hitArea(of: target, renderSize: renderSize, fitted: fitted, scale: scale)
                    }
                    if let selected = all.first(where: { $0.id == store.selectedClipID }) {
                        controls(
                            for: selected, renderSize: renderSize, fitted: fitted, scale: scale)
                    }
                    guides(in: fitted)
                }
                .coordinateSpace(name: Self.space)
            }
        }
    }

    // MARK: CanvasTargets

    private func targets(renderSize: CGSize) -> [CanvasTarget] {
        visualTargets(renderSize: renderSize) + textTargets(renderSize: renderSize)
    }

    private func activeClips(in tracks: [Track]) -> [Clip] {
        let time = store.playheadInSeconds
        return tracks.flatMap(\.clips).filter {
            $0.startInSeconds <= time && time < $0.endInSeconds
        }
    }

    private func visualTargets(renderSize: CGSize) -> [CanvasTarget] {
        let time = store.playheadInSeconds
        let clips = activeClips(in: store.project.videoTracksTopFirst.reversed())
        return clips.map { $0.presented(atTimelineTime: time) }.compactMap { clip in
            guard let base = visualFrames[clip.id] else { return nil }
            return CanvasTarget(
                id: clip.id, isText: false,
                center: CGPoint(
                    x: base.midX + clip.offsetX * renderSize.width,
                    y: base.midY + clip.offsetY * renderSize.height
                ),
                size: CGSize(width: base.width * clip.scale, height: base.height * clip.scale),
                rotationInDegrees: clip.rotationInDegrees
            )
        }
    }

    private func textTargets(renderSize: CGSize) -> [CanvasTarget] {
        activeClips(in: store.project.tracks(withRole: .text)).compactMap { clip in
            guard let layer = clip.textLayer else { return nil }
            return CanvasTarget(
                id: clip.id, isText: true,
                center: CGPoint(
                    x: layer.positionX * renderSize.width, y: layer.positionY * renderSize.height),
                size: TextOverlayLayers.textSize(of: layer, renderSize: renderSize),
                rotationInDegrees: layer.rotationInDegrees
            )
        }
    }

    // MARK: Views

    private func screenCenter(of target: CanvasTarget, fitted: CGRect, scale: Double) -> CGPoint {
        CGPoint(x: fitted.minX + target.center.x * scale, y: fitted.minY + target.center.y * scale)
    }

    private func hitArea(
        of target: CanvasTarget, renderSize: CGSize, fitted: CGRect, scale: Double
    ) -> some View {
        let center = screenCenter(of: target, fitted: fitted, scale: scale)
        return Rectangle()
            .fill(Palette.onMedia.opacity(Design.Opacity.hitArea))
            .overlay {
                Rectangle().strokeBorder(
                    Color.accentColor.opacity(outlineOpacity(of: target)),
                    style: StrokeStyle(lineWidth: Design.Stroke.hairline, dash: Design.Stroke.dash)
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

    private func controls(
        for target: CanvasTarget, renderSize: CGSize, fitted: CGRect, scale: Double
    ) -> some View {
        let center = screenCenter(of: target, fitted: fitted, scale: scale)
        let halfWidth = max(target.size.width * scale, Self.minimumHandleSide) / 2
        let halfHeight = max(target.size.height * scale, Self.minimumHandleSide) / 2
        func rotated(_ x: Double, _ y: Double) -> CGPoint {
            CanvasGeometry.rotated(x, y, around: center, degrees: target.rotationInDegrees)
        }
        let corners = [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]
        let knob = rotated(0, -halfHeight - Self.rotationStem)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: rotated(0, -halfHeight))
                path.addLine(to: knob)
            }
            .stroke(Color.accentColor, lineWidth: Design.Stroke.hairline)
            ForEach(corners.indices, id: \.self) { index in
                let corner = corners[index]
                cornerHandle(at: rotated(corner.0 * halfWidth, corner.1 * halfHeight))
                    .gesture(resize(target, center: center))
            }
            rotationHandle(at: knob)
                .gesture(rotate(target, center: center))
        }
    }

    private func cornerHandle(at point: CGPoint) -> some View {
        Rectangle()
            .fill(.white)
            .overlay(Rectangle().stroke(Color.accentColor, lineWidth: Design.Stroke.regular))
            .frame(width: Self.cornerSize, height: Self.cornerSize)
            .position(point)
    }

    private func rotationHandle(at point: CGPoint) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: Design.Stroke.regular))
            .frame(width: Self.rotationKnob, height: Self.rotationKnob)
            .position(point)
    }

    private func guides(in fitted: CGRect) -> some View {
        ZStack {
            if reachedEdges.contains(.left) {
                line(from: fitted.minX, fitted.minY, to: fitted.minX, fitted.maxY)
            }
            if reachedEdges.contains(.right) {
                line(from: fitted.maxX, fitted.minY, to: fitted.maxX, fitted.maxY)
            }
            if reachedEdges.contains(.top) {
                line(from: fitted.minX, fitted.minY, to: fitted.maxX, fitted.minY)
            }
            if reachedEdges.contains(.bottom) {
                line(from: fitted.minX, fitted.maxY, to: fitted.maxX, fitted.maxY)
            }
            if centeredAxes.contains(.horizontal) {
                line(
                    from: fitted.midX, fitted.minY, to: fitted.midX, fitted.maxY,
                    color: Self.centerGuideColor)
            }
            if centeredAxes.contains(.vertical) {
                line(
                    from: fitted.minX, fitted.midY, to: fitted.maxX, fitted.midY,
                    color: Self.centerGuideColor)
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

    private func beginSession(for target: CanvasTarget) -> Session? {
        if let session { return session }
        guard
            let clip = store.project.clip(withID: target.id)?.presented(
                atTimelineTime: store.playheadInSeconds)
        else { return nil }
        store.selectClip(target.id)
        let origin = dragStart(of: target, clip: clip)
        let started = Session(
            offsetX: origin.x,
            offsetY: origin.y,
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

    private func move(_ target: CanvasTarget, renderSize: CGSize, scale: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard scale > 0, let start = beginSession(for: target) else { return }
                let raw = CGSize(
                    width: (value.location.x - value.startLocation.x) / scale,
                    height: (value.location.y - value.startLocation.y) / scale
                )
                let delta = CanvasGeometry.magnetized(
                    raw, from: start.bounds, canvas: renderSize, reach: Self.magnetDistance / scale)
                applyDrag(to: target, from: start, delta: delta, renderSize: renderSize)
                let placed = start.bounds.offsetBy(dx: delta.width, dy: delta.height)
                reachedEdges = CanvasGeometry.edges(of: placed, moving: raw, in: renderSize)
                centeredAxes = CanvasGeometry.centeredAxes(of: placed, in: renderSize)
            }
            .onEnded { _ in endSession() }
    }

    private func applyDrag(
        to target: CanvasTarget, from start: Session, delta: CGSize, renderSize: CGSize
    ) {
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
    }

    private func resize(_ target: CanvasTarget, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard let start = beginSession(for: target) else { return }
                let startDistance = hypot(
                    value.startLocation.x - center.x, value.startLocation.y - center.y)
                let distance = hypot(value.location.x - center.x, value.location.y - center.y)
                guard startDistance > 0 else { return }
                let ratio = distance / startDistance
                if target.isText {
                    let size = min(
                        max(start.fontSize * ratio, Self.fontSizeRange.lowerBound),
                        Self.fontSizeRange.upperBound)
                    store.updateTextLayer(of: target.id, field: "canvas-scale") {
                        $0.fontSize = size
                    }
                } else {
                    store.setTransform(
                        of: target.id, scale: start.scale * ratio,
                        rotationInDegrees: start.rotationInDegrees
                    )
                }
            }
            .onEnded { _ in endSession() }
    }

    private func rotate(_ target: CanvasTarget, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard let start = beginSession(for: target) else { return }
                let startAngle = atan2(
                    value.startLocation.y - center.y, value.startLocation.x - center.x)
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                let degrees = CanvasGeometry.snappedAngle(
                    start.rotationInDegrees + (angle - startAngle) * 180 / .pi)
                if target.isText {
                    store.updateTextLayer(of: target.id, field: "canvas-rotate") {
                        $0.rotationInDegrees = degrees
                    }
                } else {
                    store.setTransform(
                        of: target.id, scale: start.scale, rotationInDegrees: degrees)
                }
            }
            .onEnded { _ in endSession() }
    }

    // MARK: Magnet and guides

}

#Preview {
    CanvasDragOverlay(
        store: PreviewFixtures.store(), renderSize: CGSize(width: 1920, height: 1080),
        visualFrames: [PreviewFixtures.videoClip.id: CGRect(x: 0, y: 0, width: 1920, height: 1080)]
    )
    .frame(width: 480, height: 270)
}
