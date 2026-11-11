import SwiftUI

enum SliderValueDisplay {
    case percent, signedNumber

    func text(for value: Double) -> String {
        switch self {
        case .percent: return "\(Int((value * 100).rounded()))%"
        case .signedNumber: return String(format: "%+.0f", value * 100)
        }
    }
}

struct EffectsInspector: View {
    let store: ProjectStore
    let clip: Clip

    private func presetTint(for preset: ColorPreset) -> Color? {
        guard clip.color == preset.adjustments else { return nil }
        return .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("inspector.effects.section")).font(.subheadline.bold())
            presets
            slider("inspector.effects.brightness", \.brightness, ColorAdjustments.brightnessRange, display: .percent)
            slider("inspector.effects.contrast", \.contrast, ColorAdjustments.contrastRange, display: .percent)
            slider("inspector.effects.saturation", \.saturation, ColorAdjustments.saturationRange, display: .percent)
            slider("inspector.effects.temperature", \.temperature, ColorAdjustments.temperatureRange, display: .signedNumber)
            Button(localized("inspector.effects.reset")) { store.setColor(of: clip.id, to: ColorAdjustments()) }
                .disabled(clip.color.isIdentity)
            Divider()
            Text(localized("inspector.crop.section")).font(.subheadline.bold())
            cropSlider("inspector.crop.left", \.left)
            cropSlider("inspector.crop.right", \.right)
            cropSlider("inspector.crop.top", \.top)
            cropSlider("inspector.crop.bottom", \.bottom)
            Text(localized("inspector.crop.hint")).font(.caption).foregroundStyle(.secondary)
            Button(localized("inspector.crop.reset")) { store.setCrop(of: clip.id, to: CropInsets()) }
                .disabled(clip.crop.isNone)
        }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localized("inspector.effects.presets")).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], alignment: .leading, spacing: 4) {
                ForEach(ColorPreset.allCases, id: \.self) { preset in
                    Button(Self.title(of: preset)) { store.setColor(of: clip.id, to: preset.adjustments) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(presetTint(for: preset))
                }
            }
        }
    }

    private func slider(
        _ key: String.LocalizationValue,
        _ path: WritableKeyPath<ColorAdjustments, Double>,
        _ range: ClosedRange<Double>,
        display: SliderValueDisplay
    ) -> some View {
        let value = clip.color[keyPath: path]
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(localized(key))
                Spacer()
                Text(display.text(for: value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        var adjustments = clip.color
                        adjustments[keyPath: path] = newValue
                        store.setColor(of: clip.id, to: adjustments)
                    }
                ),
                in: range
            )
        }
    }

    private func cropSlider(_ key: String.LocalizationValue, _ path: WritableKeyPath<CropInsets, Double>) -> some View {
        let value = clip.crop[keyPath: path]
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(localized(key))
                Spacer()
                Text("\(Int((value * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        var insets = clip.crop
                        insets[keyPath: path] = newValue
                        store.setCrop(of: clip.id, to: insets)
                    }
                ),
                in: 0...CropInsets.maximumPerAxis
            )
        }
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
