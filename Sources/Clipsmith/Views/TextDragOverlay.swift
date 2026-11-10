import SwiftUI

/// Transparent layer over the timeline preview that lets the user click and drag text on the canvas.
struct TextDragOverlay: View {
    let store: ProjectStore
    let renderSize: CGSize?

    @State private var dragStart: TextLayer?

    var body: some View {
        GeometryReader { proxy in
            if let renderSize, renderSize.width > 0, renderSize.height > 0 {
                let fitted = Self.fittedRect(of: renderSize, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    ForEach(visibleTextClips) { clip in
                        handle(for: clip, renderSize: renderSize, fitted: fitted)
                    }
                }
            }
        }
    }

    private var visibleTextClips: [Clip] {
        let time = store.playheadInSeconds
        return store.project.tracks
            .filter { $0.role == .text }
            .flatMap(\.clips)
            .filter { $0.textLayer != nil && $0.startInSeconds <= time && time < $0.endInSeconds }
    }

    private func handle(for clip: Clip, renderSize: CGSize, fitted: CGRect) -> some View {
        let layer = clip.textLayer ?? TextLayer(content: "")
        let scale = fitted.width / renderSize.width
        let size = TextOverlayLayers.textSize(of: layer, renderSize: renderSize)
        let width = max(size.width * scale, 24)
        let height = max(size.height * scale, 24)
        let isSelected = store.selectedClipID == clip.id
        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay {
                Rectangle().strokeBorder(
                    Color.accentColor.opacity(isSelected ? 0.9 : 0),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .position(
                x: fitted.minX + layer.positionX * fitted.width,
                y: fitted.minY + layer.positionY * fitted.height
            )
            .onHover { inside in
                if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
            }
            .gesture(drag(clip: clip, fitted: fitted))
    }

    private func drag(clip: Clip, fitted: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = clip.textLayer
                    store.selectClip(clip.id)
                }
                guard let start = dragStart, fitted.width > 0, fitted.height > 0 else { return }
                let x = min(max(start.positionX + value.translation.width / fitted.width, 0), 1)
                let y = min(max(start.positionY + value.translation.height / fitted.height, 0), 1)
                store.updateTextLayer(of: clip.id, field: "canvas-drag") {
                    $0.positionX = x
                    $0.positionY = y
                }
            }
            .onEnded { _ in dragStart = nil }
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
