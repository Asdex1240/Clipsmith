import SwiftUI

struct PreviewPlaybackControls: View {
    let controller: PlayerController
    let store: ProjectStore

    var body: some View {
        PlaybackControls(
            position: position, isPlaying: controller.isPlaying, canPlay: true,
            onTogglePlayback: controller.togglePlayback, onGoToStart: goToStart,
            onStep: step(bySeconds:), onScrub: scrub(to:)
        )
    }

    private var position: PlaybackPosition {
        switch controller.mode {
        case .timeline:
            return PlaybackPosition(
                currentInSeconds: store.playheadInSeconds,
                durationInSeconds: store.project.durationInSeconds)
        case .highlight:
            return PlaybackPosition(
                currentInSeconds: controller.highlightTimeInSeconds,
                durationInSeconds: controller.highlightDurationInSeconds)
        case .source:
            return PlaybackPosition(
                currentInSeconds: controller.sourceTimeInSeconds,
                durationInSeconds: controller.sourceItem?.durationInSeconds ?? 0)
        }
    }

    private func goToStart() {
        switch controller.mode {
        case .timeline: store.goToStart()
        case .highlight, .source: controller.seek(to: 0)
        }
    }

    private func step(bySeconds seconds: TimeInterval) {
        scrub(to: position.time(offsetBy: seconds))
    }

    private func scrub(to seconds: TimeInterval) {
        switch controller.mode {
        case .timeline: store.movePlayhead(to: seconds)
        case .highlight, .source: controller.seek(to: seconds)
        }
    }
}

#Preview {
    PreviewPlaybackControls(controller: PlayerController(), store: PreviewFixtures.store())
        .padding()
}
