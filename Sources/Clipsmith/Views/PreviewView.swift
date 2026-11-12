import SwiftUI

struct PreviewView: View {
    let controller: PlayerController
    let store: ProjectStore
    var proxies: ProxyStore?
    var highlightPreview: HighlightPreviewController?
    let settings: PreviewSettings
    let onSelectTimeline: () -> Void
    @AppStorage("preview.guides") private var showsGuides = false
    @State private var pointerIsIdle = false
    @State private var pointerActivity = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            highlightBanner
            surface
                .overlay { guides }
                .overlay(alignment: .bottom) { floatingControls }
                .onContinuousHover { phase in
                    if case .active = phase { registerPointerActivity() }
                }
                .task(id: pointerActivity) { await waitForPointerToRest() }
            Divider()
            PreviewOptionsBar(
                controller: controller, store: store, proxies: proxies, settings: settings,
                showsGuides: $showsGuides, onSelectTimeline: onSelectTimeline)
        }
    }

    private var canPlay: Bool {
        switch controller.mode {
        case .timeline: return controller.hasTimeline
        case .highlight: return controller.hasHighlight
        case .source: return !controller.sourceIsStillImage && controller.sourceItem != nil
        }
    }

    private var controlsAreVisible: Bool {
        ControlsVisibility(isPlaying: controller.isPlaying, pointerIsIdle: pointerIsIdle)
            .isVisible
    }

    @ViewBuilder
    private var floatingControls: some View {
        if canPlay {
            PreviewPlaybackControls(controller: controller, store: store)
                .padding(Design.Spacing.spacious)
                .opacity(controlsOpacity)
                .animation(controlsAnimation, value: controlsAreVisible)
        }
    }

    private var controlsOpacity: Double {
        if controlsAreVisible { return 1 }
        return 0
    }

    private var controlsAnimation: Animation? {
        if reduceMotion { return nil }
        return .easeInOut(duration: Design.Motion.standard)
    }

    @ViewBuilder
    private var guides: some View {
        if showsGuides {
            GuidesOverlay(renderSize: guideRenderSize)
        }
    }

    private var guideRenderSize: CGSize? {
        switch controller.mode {
        case .timeline: return controller.timelineOverlay?.renderSize
        case .highlight: return controller.highlightOverlay?.renderSize
        case .source: return nil
        }
    }

    private func registerPointerActivity() {
        pointerIsIdle = false
        pointerActivity += 1
    }

    private func waitForPointerToRest() async {
        try? await Task.sleep(for: .seconds(ControlsVisibility.hideDelayInSeconds))
        pointerIsIdle = true
    }

    @ViewBuilder
    private var highlightBanner: some View {
        if controller.mode == .highlight, let highlightPreview {
            HStack(spacing: Design.Spacing.regular) {
                Image(systemName: "rectangle.portrait")
                    .foregroundStyle(Palette.highlight)
                    .accessibilityHidden(true)
                Text(highlightTitle(highlightPreview))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Button(localized("highlight.preview.close"), action: highlightPreview.close)
            }
            .padding(Design.Spacing.regular)
            .background(Palette.highlight.opacity(Design.Opacity.highlightBackground))
        }
    }

    private func highlightTitle(_ preview: HighlightPreviewController) -> String {
        let name = preview.activeHighlight?.name ?? ""
        return String(format: localized("highlight.preview.title"), name)
    }

    @ViewBuilder
    private var surface: some View {
        switch controller.mode {
        case .timeline:
            timelineSurface
        case .source:
            sourceSurface
        case .highlight:
            highlightSurface
        }
    }

    @ViewBuilder
    private var highlightSurface: some View {
        if controller.hasHighlight {
            PlayerSurface(
                player: controller.player, overlay: controller.highlightOverlay,
                time: controller.highlightTimeInSeconds
            )
            .background(.black)
        } else {
            emptyState("rectangle.portrait", localized("highlight.preview.empty"))
        }
    }

    @ViewBuilder
    private var timelineSurface: some View {
        if controller.hasTimeline {
            PlayerSurface(
                player: controller.player,
                overlay: liveOverlay,
                time: store.playheadInSeconds
            )
            .background(.black)
            .overlay {
                CanvasDragOverlay(
                    store: store,
                    renderSize: controller.timelineOverlay?.renderSize,
                    visualFrames: controller.visualFrames
                )
            }
        } else {
            emptyState("film.stack", localized("preview.timelineEmpty"))
        }
    }

    private var liveOverlay: TextOverlay? {
        guard let renderSize = controller.timelineOverlay?.renderSize else { return nil }
        let clips = store.project.tracks.filter { $0.role == .text }.flatMap(\.clips)
        return TextOverlay(clips: clips, renderSize: renderSize)
    }

    @ViewBuilder
    private var sourceSurface: some View {
        if let item = controller.sourceItem {
            if item.kind == .image, let image = NSImage(contentsOf: item.url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                PlayerSurface(player: controller.player).background(.black)
            }
        } else {
            emptyState("play.rectangle", localized("preview.empty"))
        }
    }

    private func emptyState(_ symbol: String, _ message: String) -> some View {
        EmptyStateView(systemImage: symbol, message: message)
            .background(.background.secondary)
    }
}

#Preview {
    PreviewView(
        controller: PlayerController(), store: PreviewFixtures.store(), settings: PreviewSettings(),
        onSelectTimeline: {}
    )
    .frame(width: 640, height: 400)
}
