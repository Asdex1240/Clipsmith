import SwiftUI

struct VisualInspector: View {
    let store: ProjectStore
    let clip: Clip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("inspector.visual.section")).font(.subheadline.bold())
            Picker(localized("inspector.visual.framing"), selection: framingBinding) {
                Text(localized("inspector.visual.fit")).tag(FitMode.fit)
                Text(localized("inspector.visual.fill")).tag(FitMode.fill)
            }
            .pickerStyle(.segmented)
            Text(localized(clip.fitMode == .fit ? "inspector.visual.fit.hint" : "inspector.visual.fill.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
            slider("inspector.visual.scale", scaleBinding, Clip.scaleRange, "\(Int((clip.scale * 100).rounded()))%")
            slider("inspector.visual.rotation", rotationBinding, -180...180, "\(Int(clip.rotationInDegrees.rounded()))°")
            Button(localized("inspector.visual.reset")) { store.resetTransform(of: clip.id) }
                .disabled(isUntransformed)
        }
    }

    private var isUntransformed: Bool {
        clip.offsetX == 0 && clip.offsetY == 0 && clip.scale == 1 && clip.rotationInDegrees == 0
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { clip.scale },
            set: { store.setTransform(of: clip.id, scale: $0, rotationInDegrees: clip.rotationInDegrees) }
        )
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: { clip.rotationInDegrees },
            set: { store.setTransform(of: clip.id, scale: clip.scale, rotationInDegrees: $0) }
        )
    }

    private func slider(
        _ key: String.LocalizationValue,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
        _ valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(localized(key))
                Spacer()
                Text(valueText).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private var framingBinding: Binding<FitMode> {
        Binding(get: { clip.fitMode }, set: { store.setFitMode(of: clip.id, to: $0) })
    }
}
