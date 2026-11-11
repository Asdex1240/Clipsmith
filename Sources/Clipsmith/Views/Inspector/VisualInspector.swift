import SwiftUI

struct VisualInspector: View {
    let store: ProjectStore
    let clip: Clip

    private var fitHintKey: String.LocalizationValue {
        if clip.fitMode == .fit { return "inspector.visual.fit.hint" }
        return "inspector.visual.fill.hint"
    }

    private var keyframesHintKey: String.LocalizationValue {
        if clip.isAnimated { return "inspector.keyframes.hint.active" }
        return "inspector.keyframes.hint"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("inspector.visual.section")).font(.subheadline.bold())
            Picker(localized("inspector.visual.framing"), selection: framingBinding) {
                Text(localized("inspector.visual.fit")).tag(FitMode.fit)
                Text(localized("inspector.visual.fill")).tag(FitMode.fill)
            }
            .pickerStyle(.segmented)
            Text(localized(fitHintKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            slider("inspector.visual.scale", scaleBinding, Clip.scaleRange, "\(Int((clip.scale * 100).rounded()))%")
            slider("inspector.visual.rotation", rotationBinding, -180...180, "\(Int(clip.rotationInDegrees.rounded()))°")
            slider("inspector.visual.opacity", opacityBinding, 0...1, "\(Int((clip.opacity * 100).rounded()))%")
            Button(localized("inspector.visual.reset")) { store.resetTransform(of: clip.id) }
                .disabled(isUntransformed)
            keyframes
        }
    }

    private var isUntransformed: Bool {
        clip.offsetX == 0 && clip.offsetY == 0 && clip.scale == 1 && clip.rotationInDegrees == 0 && !clip.isAnimated
    }

    private var playheadIsInsideClip: Bool {
        store.playheadInSeconds >= clip.startInSeconds && store.playheadInSeconds <= clip.endInSeconds
    }

    private var keyframes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(localized("inspector.keyframes.section")).font(.subheadline.bold())
            Text(localized(keyframesHintKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(clip.keyframes) { frame in
                HStack {
                    Image(systemName: "diamond.fill").foregroundStyle(.yellow).font(.caption)
                    Text((clip.startInSeconds + frame.timeInSeconds).clockString).monospacedDigit()
                    Spacer()
                    EasingMenu(easing: frame.easing) { store.setKeyframeEasing($0, for: frame.id, in: clip.id) }
                    Button { store.movePlayhead(to: clip.startInSeconds + frame.timeInSeconds) } label: {
                        Image(systemName: "arrow.right.to.line")
                    }
                    .buttonStyle(.borderless)
                    .help(localized("inspector.keyframes.go"))
                    Button { store.removeKeyframe(frame.id, from: clip.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help(localized("inspector.keyframes.remove"))
                }
            }
            HStack {
                Button(localized("inspector.keyframes.add")) { store.addKeyframeAtPlayhead(to: clip.id) }
                    .disabled(!playheadIsInsideClip)
                if clip.isAnimated {
                    Button(localized("inspector.keyframes.clear")) { store.clearKeyframes(of: clip.id) }
                }
            }
        }
    }

    private var opacityBinding: Binding<Double> {
        Binding(get: { clip.opacity }, set: { store.setOpacity(of: clip.id, to: $0) })
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
