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
                overlay: controller.timelineOverlay,
                revision: controller.timelineRevision
            )
            .background(.black)
        } else {
            emptyState(localized("preview.timelineEmpty"))
        }
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
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!canPlay)
            Text("\(store.playheadInSeconds.clockString) / \(store.project.durationInSeconds.clockString)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer()
            canvasPicker
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

    private var canvasPicker: some View {
        Picker("", selection: Binding(get: { store.project.canvas }, set: store.setCanvas)) {
            Text(localized("canvas.landscape")).tag(CanvasFormat.landscape)
            Text(localized("canvas.portrait")).tag(CanvasFormat.portrait)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help(localized("canvas.help"))
    }
}
