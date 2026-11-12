import SwiftUI

struct VisualInspector: View {
    let store: ProjectStore
    let clip: Clip

    private var fitHintKey: String.LocalizationValue {
        switch clip.fitMode {
        case .fit: return "inspector.visual.fit.hint"
        case .fill: return "inspector.visual.fill.hint"
        case .blur: return "inspector.visual.blur.hint"
        }
    }

    private var keyframesHintKey: String.LocalizationValue {
        if clip.isAnimated { return "inspector.keyframes.hint.active" }
        return "inspector.keyframes.hint"
    }

    private static let neutralScale = 1.0
    private static let neutralRotation = 0.0
    private static let fullOpacity = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
            framingSection
            keyframesSection
        }
    }

    private var framingSection: some View {
        InspectorSection(.framing) {
            Picker(localized("inspector.visual.framing"), selection: framingBinding) {
                Text(localized("inspector.visual.fit")).tag(FitMode.fit)
                Text(localized("inspector.visual.fill")).tag(FitMode.fill)
                Text(localized("inspector.visual.blur")).tag(FitMode.blur)
            }
            .pickerStyle(.segmented)
            Text(localized(fitHintKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            ParameterSlider(
                title: localized("inspector.visual.scale"), value: scaleBinding,
                range: Clip.scaleRange, unit: .percent, defaultValue: Self.neutralScale)
            ParameterSlider(
                title: localized("inspector.visual.rotation"), value: rotationBinding,
                range: -180...180, unit: .degrees, defaultValue: Self.neutralRotation)
            ParameterSlider(
                title: localized("inspector.visual.opacity"), value: opacityBinding,
                range: 0...1, unit: .percent, defaultValue: Self.fullOpacity)
            Button(localized("inspector.visual.reset")) { store.resetTransform(of: clip.id) }
                .disabled(isUntransformed)
        }
    }

    private var isUntransformed: Bool {
        clip.offsetX == 0 && clip.offsetY == 0 && clip.scale == 1 && clip.rotationInDegrees == 0
            && !clip.isAnimated
    }

    private var keyframesSection: some View {
        InspectorSection(.keyframes) {
            Text(localized(keyframesHintKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(clip.keyframes) { frame in
                HStack {
                    Image(systemName: "diamond.fill").foregroundStyle(Palette.keyframe).font(
                        .caption)
                    Text((clip.startInSeconds + frame.timeInSeconds).clockString).monospacedDigit()
                    Spacer()
                    EasingMenu(easing: frame.easing) {
                        store.setKeyframeEasing($0, for: frame.id, in: clip.id)
                    }
                    Button {
                        store.movePlayhead(to: clip.startInSeconds + frame.timeInSeconds)
                    } label: {
                        Image(systemName: "arrow.right.to.line")
                    }
                    .buttonStyle(.borderless)
                    .help(localized("inspector.keyframes.go"))
                    .accessibilityLabel(localized("inspector.keyframes.go"))
                    Button {
                        store.removeKeyframe(frame.id, from: clip.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(localized("inspector.keyframes.remove"))
                    .accessibilityLabel(localized("inspector.keyframes.remove"))
                }
            }
            HStack {
                AddKeyframeButton(store: store, clip: clip)
                if clip.isAnimated {
                    Button(localized("inspector.keyframes.clear")) {
                        store.clearKeyframes(of: clip.id)
                    }
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
            set: {
                store.setTransform(
                    of: clip.id, scale: $0, rotationInDegrees: clip.rotationInDegrees)
            }
        )
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: { clip.rotationInDegrees },
            set: { store.setTransform(of: clip.id, scale: clip.scale, rotationInDegrees: $0) }
        )
    }

    private var framingBinding: Binding<FitMode> {
        Binding(get: { clip.fitMode }, set: { store.setFitMode(of: clip.id, to: $0) })
    }
}

#Preview {
    VisualInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
