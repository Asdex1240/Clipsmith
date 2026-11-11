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

final class TextOverlayHostView: NSView {
    private let container = CALayer()
    private var shownOverlay: TextOverlay?
    private var entries: [(clip: Clip, layer: CALayer)] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        container.anchorPoint = .zero
        layer?.addSublayer(container)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ overlay: TextOverlay?, at time: TimeInterval) {
        var visibleOverlay: TextOverlay?
        if let overlay, !overlay.isEmpty { visibleOverlay = overlay }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if visibleOverlay != shownOverlay { replaceEntries(with: visibleOverlay) }
        let renderHeight = shownOverlay?.renderSize.height ?? 0
        entries.forEach { update($0, at: time, renderHeight: renderHeight) }
        CATransaction.commit()
    }

    private func replaceEntries(with overlay: TextOverlay?) {
        shownOverlay = overlay
        entries.forEach { $0.layer.removeFromSuperlayer() }
        entries = overlay.map(TextOverlayLayers.makeStaticLayers) ?? []
        entries.forEach { container.addSublayer($0.layer) }
        container.bounds = CGRect(origin: .zero, size: overlay?.renderSize ?? .zero)
        needsLayout = true
    }

    private func update(
        _ entry: (clip: Clip, layer: CALayer), at time: TimeInterval, renderHeight: Double
    ) {
        let isShown = entry.clip.startInSeconds <= time && time < entry.clip.endInSeconds
        guard isShown, let text = entry.clip.textLayer else {
            entry.layer.opacity = 0
            return
        }
        let state = text.animation.state(
            atClipTime: time - entry.clip.startInSeconds, clipDuration: entry.clip.durationInSeconds
        )
        entry.layer.opacity = Float(state.opacity)
        entry.layer.setAffineTransform(
            TextOverlayLayers.transform(for: text, state: state, renderHeight: renderHeight))
    }

    override func layout() {
        super.layout()
        guard let size = shownOverlay?.renderSize, size.width > 0, size.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        container.position = CGPoint(
            x: (bounds.width - size.width * scale) / 2, y: (bounds.height - size.height * scale) / 2
        )
        container.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }
}
