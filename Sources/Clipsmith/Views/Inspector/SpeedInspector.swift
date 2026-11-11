import SwiftUI

struct SpeedInspector: View {
    let store: ProjectStore
    let clip: Clip

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
        }
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
