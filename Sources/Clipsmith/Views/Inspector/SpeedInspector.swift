import SwiftUI

struct SpeedInspector: View {
    let store: ProjectStore
    let clip: Clip

    @State private var momentFactor = SlowMoment.defaultFactor
    @State private var momentDuration = SlowMoment.defaultSourceDurationInSeconds
    @State private var mutesAudio = true
    @State private var momentMessage: String?

    private static let presets: [Double] = [0.25, 0.5, 1, 1.5, 2, 4]
    private static let selectionTolerance = 0.001

    var body: some View {
        InspectorSection(.speed) {
            VStack(alignment: .leading, spacing: Design.Spacing.hairline) {
                HStack {
                    Text(localized("inspector.speed.rate"))
                    Spacer()
                    Text(Self.label(for: clip.speed)).monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(
                    value: logBinding,
                    in: log2(Clip.speedRange.lowerBound)...log2(Clip.speedRange.upperBound))
            }
            PresetGrid(
                items: Self.presets,
                title: Self.label(for:),
                isSelected: { abs(clip.speed - $0) < Self.selectionTolerance },
                action: { store.setSpeed(of: clip.id, to: $0) }
            )
            Text(
                String(
                    format: localized("inspector.speed.duration"),
                    clip.durationInSeconds.clockString)
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            slowMoment
        }
    }

    @ViewBuilder
    private var slowMoment: some View {
        Divider()
        Text(localized("inspector.slowMoment.title")).font(.subheadline.bold())
        ParameterSlider(
            title: localized("inspector.slowMoment.speed"), value: $momentFactor,
            range: SlowMoment.factorRange, unit: .multiplier, defaultValue: SlowMoment.defaultFactor)
        ParameterSlider(
            title: localized("inspector.slowMoment.length"), value: $momentDuration,
            range: SlowMoment.sourceDurationRange, unit: .seconds,
            defaultValue: SlowMoment.defaultSourceDurationInSeconds)
        Toggle(localized("inspector.slowMoment.mute"), isOn: $mutesAudio)
        Button(localized("inspector.slowMoment.apply")) {
            let added = store.addSlowMoment(
                to: clip.id, at: store.playheadInSeconds, sourceDuration: momentDuration,
                factor: momentFactor, mutesAudio: mutesAudio)
            momentMessage = localized(
                added ? "inspector.slowMoment.done" : "inspector.slowMoment.noRoom")
        }
        if let momentMessage {
            Text(momentMessage).font(.caption).foregroundStyle(.secondary)
        }
        Text(localized("inspector.slowMoment.hint")).font(.caption).foregroundStyle(.secondary)
    }

    private var logBinding: Binding<Double> {
        Binding(
            get: { log2(clip.speed) },
            set: { store.setSpeed(of: clip.id, to: Self.snapped(pow(2, $0))) }
        )
    }

    static func snapped(_ speed: Double) -> Double {
        presets.first { abs($0 - speed) / $0 < 0.03 } ?? (speed * 100).rounded() / 100
    }

    static func label(for speed: Double) -> String {
        guard speed == speed.rounded() else { return String(format: "%g", speed) + "×" }
        return String(Int(speed)) + "×"
    }
}

#Preview {
    SpeedInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
