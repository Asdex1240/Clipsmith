import SwiftUI

struct PlaybackControls: View {
    let position: PlaybackPosition
    let isPlaying: Bool
    let canPlay: Bool
    let onTogglePlayback: () -> Void
    let onGoToStart: () -> Void
    let onStep: (TimeInterval) -> Void
    let onScrub: (TimeInterval) -> Void

    private static let frameStepInSeconds: TimeInterval = 1.0 / 30
    private static let scrubberWidth: CGFloat = 220
    private static let timecodeWidth: CGFloat = 112

    var body: some View {
        HStack(spacing: Design.Spacing.cozy) {
            button("shortcut.goToStart", "backward.end.fill", action: onGoToStart)
            button("shortcut.stepBackward", "backward.frame.fill") {
                onStep(-Self.frameStepInSeconds)
            }
            playButton
            button("shortcut.stepForward", "forward.frame.fill") {
                onStep(Self.frameStepInSeconds)
            }
            Slider(value: scrubBinding, in: 0...1)
                .frame(width: Self.scrubberWidth)
                .controlSize(.small)
                .accessibilityLabel(localized("preview.scrub"))
                .accessibilityValue(position.text)
            Text(position.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: Self.timecodeWidth, alignment: .leading)
        }
        .disabled(!canPlay)
        .padding(.horizontal, Design.Spacing.comfortable)
        .padding(.vertical, Design.Spacing.regular)
        .cardSurface(cornerRadius: Design.Radius.extraLarge)
    }

    private var playButton: some View {
        Button(action: onTogglePlayback) {
            Image(systemName: playIcon)
                .font(.title2)
                .frame(width: Design.Size.playButton)
        }
        .buttonStyle(.borderless)
        .help("\(playTitle) (\(EditorShortcuts.displayKeys(for: .togglePlayback)))")
        .accessibilityLabel(playTitle)
    }

    private func button(
        _ key: String.LocalizationValue, _ symbol: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: Design.Size.sectionIcon)
        }
        .buttonStyle(.borderless)
        .help(localized(key))
        .accessibilityLabel(localized(key))
    }

    private var scrubBinding: Binding<Double> {
        Binding(
            get: { position.fraction },
            set: { onScrub(position.time(atFraction: $0)) }
        )
    }

    private var playIcon: String {
        if isPlaying { return "pause.fill" }
        return "play.fill"
    }

    private var playTitle: String {
        if isPlaying { return localized("preview.pause") }
        return localized("preview.play")
    }
}

#Preview {
    PlaybackControls(
        position: PlaybackPosition(currentInSeconds: 12, durationInSeconds: 48), isPlaying: false,
        canPlay: true, onTogglePlayback: {}, onGoToStart: {}, onStep: { _ in }, onScrub: { _ in }
    )
    .padding()
}
