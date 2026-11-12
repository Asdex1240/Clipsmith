import SwiftUI

struct EffectsInspector: View, Equatable {
    let store: ProjectStore
    let clip: Clip

    private static let neutral = ColorAdjustments()

    static func == (lhs: EffectsInspector, rhs: EffectsInspector) -> Bool {
        lhs.store === rhs.store && lhs.clip.id == rhs.clip.id && lhs.clip.color == rhs.clip.color
            && lhs.clip.crop == rhs.clip.crop
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
            colorSection
            cropSection
        }
    }

    private var colorSection: some View {
        InspectorSection(.color) {
            PresetGrid(
                items: ColorPreset.allCases,
                title: Self.title(of:),
                isSelected: { clip.color == $0.adjustments },
                action: { store.setColor(of: clip.id, to: $0.adjustments) }
            )
            colorSlider(
                "inspector.effects.brightness", \.brightness,
                ColorAdjustments.brightnessRange, .percent)
            colorSlider(
                "inspector.effects.contrast", \.contrast, ColorAdjustments.contrastRange, .percent)
            colorSlider(
                "inspector.effects.saturation", \.saturation,
                ColorAdjustments.saturationRange, .percent)
            colorSlider(
                "inspector.effects.temperature", \.temperature,
                ColorAdjustments.temperatureRange, .signedNumber)
            Button(localized("inspector.effects.reset")) {
                store.setColor(of: clip.id, to: Self.neutral)
            }
            .disabled(clip.color.isIdentity)
        }
    }

    private var cropSection: some View {
        InspectorSection(.crop) {
            cropSlider("inspector.crop.left", \.left)
            cropSlider("inspector.crop.right", \.right)
            cropSlider("inspector.crop.top", \.top)
            cropSlider("inspector.crop.bottom", \.bottom)
            Text(localized("inspector.crop.hint")).font(.caption).foregroundStyle(.secondary)
            Button(localized("inspector.crop.reset")) {
                store.setCrop(of: clip.id, to: CropInsets())
            }
            .disabled(clip.crop.isNone)
        }
    }

    private func colorSlider(
        _ key: String.LocalizationValue,
        _ path: WritableKeyPath<ColorAdjustments, Double>,
        _ range: ClosedRange<Double>,
        _ unit: ParameterUnit
    ) -> some View {
        ParameterSlider(
            title: localized(key), value: colorBinding(path), range: range, unit: unit,
            defaultValue: Self.neutral[keyPath: path]
        )
    }

    private func colorBinding(_ path: WritableKeyPath<ColorAdjustments, Double>) -> Binding<Double>
    {
        Binding(
            get: { clip.color[keyPath: path] },
            set: { newValue in
                var adjustments = clip.color
                adjustments[keyPath: path] = newValue
                store.setColor(of: clip.id, to: adjustments)
            }
        )
    }

    private func cropSlider(
        _ key: String.LocalizationValue, _ path: WritableKeyPath<CropInsets, Double>
    ) -> some View {
        ParameterSlider(
            title: localized(key),
            value: Binding(
                get: { clip.crop[keyPath: path] },
                set: { newValue in
                    var insets = clip.crop
                    insets[keyPath: path] = newValue
                    store.setCrop(of: clip.id, to: insets)
                }
            ),
            range: 0...CropInsets.maximumPerAxis, unit: .percent, defaultValue: 0
        )
    }

    private static func title(of preset: ColorPreset) -> String {
        switch preset {
        case .none: return localized("preset.none")
        case .blackAndWhite: return localized("preset.blackAndWhite")
        case .warm: return localized("preset.warm")
        case .cool: return localized("preset.cool")
        case .vivid: return localized("preset.vivid")
        case .faded: return localized("preset.faded")
        }
    }
}

#Preview {
    EffectsInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
