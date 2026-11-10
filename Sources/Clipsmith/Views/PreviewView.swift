import SwiftUI

struct PreviewView: View {
    let controller: PlayerController

    var body: some View {
        VStack(spacing: 0) {
            surface
            Divider()
            playbackBar
        }
    }

    @ViewBuilder
    private var surface: some View {
        switch controller.currentItem?.kind {
        case nil:
            emptyState
        case .image:
            stillImage
        case .video, .audio:
            PlayerSurface(player: controller.player)
                .background(.black)
        }
    }

    private var emptyState: some View {
        ZStack {
            Rectangle().fill(.background.secondary)
            Text(localized("preview.empty")).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var stillImage: some View {
        if let url = controller.currentItem?.url, let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            emptyState
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
            .disabled(controller.currentItem == nil || controller.currentItem?.kind == .image)
            Spacer()
        }
        .padding(8)
    }
}
