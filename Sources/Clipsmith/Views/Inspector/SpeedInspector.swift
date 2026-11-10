import SwiftUI

struct SpeedInspector: View {
    let store: ProjectStore
    let clip: Clip

    private static let presets: [Double] = [0.25, 0.5, 1, 1.5, 2, 4]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("inspector.speed.section")).font(.subheadline.bold())
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(localized("inspector.speed.rate"))
                    Spacer()
                    Text(Self.label(for: clip.speed)).monospacedDigit().foregroundStyle(.secondary)
                }
                // The slider works on a log scale so 0.5× and 2× sit at equal distances from 1×.
                Slider(value: logBinding, in: log2(Clip.speedRange.lowerBound)...log2(Clip.speedRange.upperBound))
            }
            HStack(spacing: 4) {
                ForEach(Self.presets, id: \.self) { preset in
                    Button(Self.label(for: preset)) { store.setSpeed(of: clip.id, to: preset) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(abs(clip.speed - preset) < 0.001)
                }
            }
            Text(String(format: localized("inspector.speed.duration"), clip.durationInSeconds.clockString))
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

    /// Dragging lands exactly on the common rates when it gets close to them.
    static func snapped(_ speed: Double) -> Double {
        presets.first { abs($0 - speed) / $0 < 0.03 } ?? (speed * 100).rounded() / 100
    }

    static func label(for speed: Double) -> String {
        let text = speed == speed.rounded() ? String(Int(speed)) : String(format: "%g", speed)
        return text + "×"
    }
}
