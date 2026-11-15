import SwiftUI

struct ExternalPreviewView: View {
    let controller: PlayerController
    let store: ProjectStore

    var body: some View {
        surface
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var surface: some View {
        switch controller.mode {
        case .timeline:
            timelineSurface
        case .highlight:
            highlightSurface
        case .source:
            sourceSurface
        }
    }

    @ViewBuilder
    private var timelineSurface: some View {
        if controller.hasTimeline {
            PlayerSurface(
                player: controller.player,
                overlay: LiveTextOverlay.timeline(of: store, in: controller),
                time: store.playheadInSeconds)
        }
    }

    @ViewBuilder
    private var highlightSurface: some View {
        if controller.hasHighlight {
            PlayerSurface(
                player: controller.player, overlay: controller.highlightOverlay,
                time: controller.highlightTimeInSeconds)
        }
    }

    @ViewBuilder
    private var sourceSurface: some View {
        if let item = controller.sourceItem {
            if item.kind == .image, let image = NSImage(contentsOf: item.url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                PlayerSurface(player: controller.player)
            }
        }
    }
}

#Preview {
    ExternalPreviewView(controller: PlayerController(), store: PreviewFixtures.store())
        .frame(width: 640, height: 360)
}
