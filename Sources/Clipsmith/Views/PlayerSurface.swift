import AVKit
import SwiftUI

struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    var overlay: TextOverlay?
    var revision = 0

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
        context.coordinator.host?.show(overlay, for: player.currentItem)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var host: TextOverlayHostView?
    }
}

final class TextOverlayHostView: NSView {
    private var synchronizedLayer: AVSynchronizedLayer?
    private var shownOverlay: TextOverlay?
    private weak var shownItem: AVPlayerItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ overlay: TextOverlay?, for item: AVPlayerItem?) {
        let visibleOverlay = overlay.flatMap { $0.isEmpty ? nil : $0 }
        guard visibleOverlay != shownOverlay || item !== shownItem else { return }
        shownOverlay = visibleOverlay
        shownItem = item
        synchronizedLayer?.removeFromSuperlayer()
        synchronizedLayer = nil
        guard let visibleOverlay, let item else { return }
        let layer = AVSynchronizedLayer(playerItem: item)
        layer.anchorPoint = .zero
        layer.bounds = CGRect(origin: .zero, size: visibleOverlay.renderSize)
        layer.addSublayer(TextOverlayLayers.makeContainer(for: visibleOverlay))
        self.layer?.addSublayer(layer)
        synchronizedLayer = layer
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let synchronizedLayer, let size = shownOverlay?.renderSize, size.width > 0, size.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        synchronizedLayer.position = .zero
        synchronizedLayer.setAffineTransform(
            CGAffineTransform(scaleX: bounds.width / size.width, y: bounds.height / size.height)
        )
        CATransaction.commit()
    }
}
