import AVKit
import SwiftUI

struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    var overlay: TextOverlay?
    var time: TimeInterval = 0

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        let host = TextOverlayHostView(frame: view.bounds)
        host.autoresizingMask = [.width, .height]
        view.contentOverlayView?.addSubview(host)
        context.coordinator.host = host
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
        context.coordinator.host?.show(overlay, at: time)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var host: TextOverlayHostView?
    }
}
