import SwiftUI

struct PreviewView: View {
    let controller: PlayerController
    let store: ProjectStore
    var proxies: ProxyStore?
    var highlightPreview: HighlightPreviewController?
    let onSelectTimeline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            highlightBanner
            surface
            Divider()
            playbackBar
        }
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
            emptyState(localized("highlight.preview.empty"))
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
            emptyState(localized("preview.timelineEmpty"))
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
            emptyState(localized("preview.empty"))
        }
    }

    private func emptyState(_ message: String) -> some View {
        ZStack {
            Rectangle().fill(.background.secondary)
            Text(message).foregroundStyle(.secondary)
        }
    }

    private var playbackBar: some View {
        HStack {
            Button(action: controller.togglePlayback) {
                Label(
                    playbackTitle,
                    systemImage: playbackIcon
                )
            }
            .disabled(!canPlay)
            .help("\(playbackTitle) (\(EditorShortcuts.displayKeys(for: .togglePlayback)))")
            Text(positionText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer()
            if controller.mode != .highlight {
                if let proxies { fastPreview(proxies) }
                CanvasPicker(store: store)
                modePicker
            }
        }
        .padding(Design.Spacing.regular)
    }

    private func fastPreview(_ proxies: ProxyStore) -> some View {
        HStack(spacing: Design.Spacing.compact) {
            if proxies.isPreparing {
                ProgressView().controlSize(.small)
                Text(String(format: localized("preview.fast.preparing"), proxies.pendingCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle(
                localized("preview.fast"),
                isOn: Binding(get: { proxies.isEnabled }, set: { proxies.setEnabled($0) })
            )
            .toggleStyle(.button)
            .help(localized("preview.fast.help"))
        }
    }

    private var positionText: String {
        if controller.mode == .highlight {
            let current = controller.highlightTimeInSeconds.clockString
            return "\(current) / \(controller.highlightDurationInSeconds.clockString)"
        }
        let current = store.playheadInSeconds.clockString
        let total = store.project.durationInSeconds.clockString
        return "\(current) / \(total)"
    }

    private var playbackTitle: String {
        if controller.isPlaying { return localized("preview.pause") }
        return localized("preview.play")
    }

    private var playbackIcon: String {
        if controller.isPlaying { return "pause.fill" }
        return "play.fill"
    }

    private var canPlay: Bool {
        switch controller.mode {
        case .timeline: return controller.hasTimeline
        case .highlight: return controller.hasHighlight
        case .source: return !controller.sourceIsStillImage && controller.sourceItem != nil
        }
    }

    private var modePicker: some View {
        Picker("", selection: modeBinding) {
            Text(localized("preview.mode.source")).tag(PlayerController.Mode.source)
            Text(localized("preview.mode.timeline")).tag(PlayerController.Mode.timeline)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var modeBinding: Binding<PlayerController.Mode> {
        Binding(
            get: { controller.mode },
            set: { newMode in
                switch newMode {
                case .timeline, .highlight: onSelectTimeline()
                case .source: controller.sourceItem.map(controller.showSource)
                }
            }
        )
    }
}

#Preview {
    PreviewView(
        controller: PlayerController(), store: PreviewFixtures.store(), onSelectTimeline: {}
    )
    .frame(width: 640, height: 400)
}
