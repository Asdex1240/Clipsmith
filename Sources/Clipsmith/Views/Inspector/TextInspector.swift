import AppKit
import SwiftUI

struct TextInspector: View {
    let store: ProjectStore
    let clip: Clip

    private static let fonts: [(name: String, postScript: String)] = [
        ("Helvetica Neue", "HelveticaNeue-Bold"),
        ("Avenir Next", "AvenirNext-Bold"),
        ("Futura", "Futura-Bold"),
        ("Georgia", "Georgia-Bold"),
        ("Impact", "Impact"),
        ("Menlo", "Menlo-Bold"),
        ("Marker Felt", "MarkerFelt-Wide"),
    ]
    private static let sizeRange = 20.0...240.0

    private var layer: TextLayer {
        clip.textLayer ?? TextLayer(content: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("inspector.text.section")).font(.subheadline.bold())
            TextField(localized("inspector.text.content"), text: binding(\.content), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Picker(localized("inspector.text.font"), selection: binding(\.fontName)) {
                ForEach(fontOptions, id: \.postScript) { Text($0.name).tag($0.postScript) }
            }
            slider("inspector.text.size", binding(\.fontSize), Self.sizeRange, "\(Int(layer.fontSize)) pt")
            ColorPicker(localized("inspector.text.color"), selection: colorBinding, supportsOpacity: false)
            slider("inspector.text.positionX", binding(\.positionX), 0...1, percent(layer.positionX))
            slider("inspector.text.positionY", binding(\.positionY), 0...1, percent(layer.positionY))
            slider("inspector.text.rotation", binding(\.rotationInDegrees), -180...180, "\(Int(layer.rotationInDegrees.rounded()))°")
            styleControls
            animationControls
        }
    }

    // MARK: Style

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(localized("inspector.textStyle.section")).font(.subheadline.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 4)], alignment: .leading, spacing: 4) {
                ForEach(TextStylePreset.allCases, id: \.self) { preset in
                    Button(Self.title(of: preset)) {
                        store.updateTextLayer(of: clip.id, field: "style") { preset.apply(to: &$0) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            slider("inspector.textStyle.outline", binding(\.strokeWidth), 0...TextLayer.maximumStrokeWidth, percent(layer.strokeWidth / TextLayer.maximumStrokeWidth))
            if layer.strokeWidth > 0 {
                ColorPicker(localized("inspector.textStyle.outlineColor"), selection: colorBinding(\.strokeColor, field: "strokeColor"), supportsOpacity: false)
            }
            Toggle(localized("inspector.textStyle.background"), isOn: backgroundToggle)
            if let background = layer.backgroundColor {
                ColorPicker(
                    localized("inspector.textStyle.backgroundColor"),
                    selection: colorBinding(\.backgroundColor, field: "background", fallback: background),
                    supportsOpacity: true
                )
            }
            Toggle(localized("inspector.textStyle.shadow"), isOn: binding(\.hasShadow))
        }
    }

    // MARK: Animation

    private var animationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(localized("inspector.textAnimation.section")).font(.subheadline.bold())
            Picker(localized("inspector.textAnimation.in"), selection: binding(\.animation.inKind)) {
                ForEach(TextAnimationKind.allCases, id: \.self) { Text(Self.title(of: $0)).tag($0) }
            }
            Picker(localized("inspector.textAnimation.out"), selection: binding(\.animation.outKind)) {
                ForEach(TextAnimationKind.allCases, id: \.self) { Text(Self.title(of: $0)).tag($0) }
            }
            if !layer.animation.isNone {
                slider(
                    "inspector.textAnimation.duration", binding(\.animation.durationInSeconds), TextAnimation.durationRange,
                    String(format: "%.1f s", layer.animation.durationInSeconds)
                )
            }
        }
    }

    static func title(of kind: TextAnimationKind) -> String {
        switch kind {
        case .none: return localized("textAnimation.none")
        case .fade: return localized("textAnimation.fade")
        case .slideUp: return localized("textAnimation.slideUp")
        case .slideDown: return localized("textAnimation.slideDown")
        case .pop: return localized("textAnimation.pop")
        }
    }

    static func title(of preset: TextStylePreset) -> String {
        switch preset {
        case .classic: return localized("textStyle.classic")
        case .outlined: return localized("textStyle.outlined")
        case .boxed: return localized("textStyle.boxed")
        case .highlight: return localized("textStyle.highlight")
        }
    }

    private var backgroundToggle: Binding<Bool> {
        Binding(
            get: { layer.backgroundColor != nil },
            set: { isOn in
                store.updateTextLayer(of: clip.id, field: "background") {
                    $0.backgroundColor = isOn ? RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.65) : nil
                }
            }
        )
    }

    private var fontOptions: [(name: String, postScript: String)] {
        let isListed = Self.fonts.contains { $0.postScript == layer.fontName }
        return isListed ? Self.fonts : Self.fonts + [(layer.fontName, layer.fontName)]
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<TextLayer, Value>) -> Binding<Value> {
        Binding(
            get: { layer[keyPath: keyPath] },
            set: { newValue in
                store.updateTextLayer(of: clip.id, field: String(describing: keyPath)) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var colorBinding: Binding<Color> {
        colorBinding(\.color, field: "color")
    }

    private func colorBinding(_ keyPath: WritableKeyPath<TextLayer, RGBAColor>, field: String) -> Binding<Color> {
        Binding(
            get: { Self.swiftUIColor(layer[keyPath: keyPath]) },
            set: { newColor in
                store.updateTextLayer(of: clip.id, field: field) { $0[keyPath: keyPath] = Self.rgba(newColor) }
            }
        )
    }

    private func colorBinding(
        _ keyPath: WritableKeyPath<TextLayer, RGBAColor?>, field: String, fallback: RGBAColor
    ) -> Binding<Color> {
        Binding(
            get: { Self.swiftUIColor(layer[keyPath: keyPath] ?? fallback) },
            set: { newColor in
                store.updateTextLayer(of: clip.id, field: field) { $0[keyPath: keyPath] = Self.rgba(newColor) }
            }
        )
    }

    private static func swiftUIColor(_ color: RGBAColor) -> Color {
        Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }

    private static func rgba(_ color: Color) -> RGBAColor {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return RGBAColor(
            red: resolved.redComponent, green: resolved.greenComponent,
            blue: resolved.blueComponent, alpha: resolved.alphaComponent
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
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
}
