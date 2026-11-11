import AVFoundation
import Combine
import Observation

@MainActor
@Observable
final class PlayerController {
    enum Mode { case source, timeline }

    private static let updateInterval = CMTime(value: 1, timescale: 30)
    private static let seekToleranceInSeconds: TimeInterval = 1.0 / 60

    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored var onTimelineTimeChange: ((TimeInterval) -> Void)?
    private(set) var mode: Mode = .timeline
    private(set) var sourceItem: MediaItem?
    private(set) var hasTimeline = false
    private(set) var timelineOverlay: TextOverlay?
    private(set) var timelineRevision = 0
    private(set) var visualFrames: [Clip.ID: CGRect] = [:]
    private(set) var isPlaying = false
    @ObservationIgnored private var timeline: BuiltComposition?
    @ObservationIgnored private var statusObservation: AnyCancellable?

    init() {
        statusObservation = player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.isPlaying = status != .paused }
        player.addPeriodicTimeObserver(forInterval: Self.updateInterval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.playerTimeDidChange(time) }
        }
    }

    var sourceIsStillImage: Bool {
        sourceItem?.kind == .image
    }

    func showSource(_ item: MediaItem) {
        mode = .source
        sourceItem = item
        player.pause()
        if sourceIsStillImage {
            player.replaceCurrentItem(with: nil)
        } else {
            player.replaceCurrentItem(with: AVPlayerItem(url: item.url))
        }
    }

    func showTimeline(at time: TimeInterval) {
        guard mode != .timeline else { return }
        mode = .timeline
        player.pause()
        installTimeline(resumingPlayback: false, at: time)
    }

    func setTimeline(_ built: BuiltComposition?, at time: TimeInterval) {
        timeline = built
        hasTimeline = built != nil
        timelineOverlay = built?.textOverlay
        visualFrames = built?.visualFrames ?? [:]
        timelineRevision += 1
        guard mode == .timeline else { return }
        installTimeline(resumingPlayback: isPlaying, at: time)
    }

    func updateTransforms(_ built: BuiltComposition) {
        timeline = built
        visualFrames = built.visualFrames
        guard mode == .timeline else { return }
        player.currentItem?.videoComposition = built.videoComposition
    }

    func seekTimeline(to time: TimeInterval) {
        guard mode == .timeline else {
            showTimeline(at: time)
            return
        }
        guard abs(player.currentTime().seconds - time) > Self.seekToleranceInSeconds else { return }
        player.seek(to: time.cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func togglePlayback() {
        guard player.currentItem != nil else { return }
        if isPlaying {
            player.pause()
        } else {
            restartIfFinished()
            player.play()
        }
    }

    private func installTimeline(resumingPlayback: Bool, at time: TimeInterval) {
        guard let timeline else {
            player.replaceCurrentItem(with: nil)
            return
        }
        player.replaceCurrentItem(with: timeline.makePlayerItem())
        Task { @MainActor in
            await player.seek(to: time.cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            if resumingPlayback { player.play() }
        }
    }

    private func restartIfFinished() {
        guard let item = player.currentItem, item.duration.isNumeric,
              item.currentTime() >= item.duration else { return }
        player.seek(to: .zero)
    }

    private func playerTimeDidChange(_ time: CMTime) {
        guard mode == .timeline, isPlaying else { return }
        onTimelineTimeChange?(time.seconds)
    }
}
