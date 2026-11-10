import AVFoundation
import Combine
import Observation

@MainActor
@Observable
final class PlayerController {
    let player = AVPlayer()
    private(set) var currentItem: MediaItem?
    private(set) var isPlaying = false
    private var statusObservation: AnyCancellable?

    init() {
        statusObservation = player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.isPlaying = status != .paused }
    }

    func load(_ item: MediaItem) {
        player.pause()
        currentItem = item
        let playable = item.kind != .image
        player.replaceCurrentItem(with: playable ? AVPlayerItem(url: item.url) : nil)
    }

    func togglePlayback() {
        guard currentItem?.kind != .image, player.currentItem != nil else { return }
        if isPlaying {
            player.pause()
        } else {
            restartIfFinished()
            player.play()
        }
    }

    private func restartIfFinished() {
        guard let item = player.currentItem, item.currentTime() >= item.duration else { return }
        player.seek(to: .zero)
    }
}
