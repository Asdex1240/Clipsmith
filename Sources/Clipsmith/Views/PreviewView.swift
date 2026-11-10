import SwiftUI

struct PreviewView: View {
    let controller: PlayerController
    let store: ProjectStore
    let onSelectTimeline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            surface
            Divider()
            playbackBar
        }
    }

    @ViewBuilder
    private var surface: some View {
        switch controller.mode {
        case .timeline:
            timelineSurface
        case .source:
            sourceSurface
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
            .overlay { CanvasDragOverlay(
                    store: store,
                    renderSize: controller.timelineOverlay?.renderSize,
                    visualFrames: controller.visualFrames
                ) }
        } else {
            emptyState(localized("preview.timelineEmpty"))
        }
    }

    /// Text from the current project, so edits show instantly without waiting for a composition rebuild.
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
                    localized(controller.isPlaying ? "preview.pause" : "preview.play"),
                    systemImage: controller.isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .disabled(!canPlay)
            Text("\(store.playheadInSeconds.clockString) / \(store.project.durationInSeconds.clockString)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer()
            CanvasPicker(store: store)
            modePicker
        }
        .padding(8)
    }

    private var canPlay: Bool {
        controller.mode == .timeline ? controller.hasTimeline : !controller.sourceIsStillImage && controller.sourceItem != nil
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
                case .timeline: onSelectTimeline()
                case .source: controller.sourceItem.map(controller.showSource)
                }
            }
        )
    }
}
