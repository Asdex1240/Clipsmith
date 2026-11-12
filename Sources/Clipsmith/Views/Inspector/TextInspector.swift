import AppKit
import SwiftUI

struct TextInspector: View, Equatable {
    private static let defaultBackgroundColor = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.65)
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

    private static let defaults = TextLayer(content: "")
    private static let noAnimation = TextAnimation()

    private var layer: TextLayer {
        clip.textLayer ?? TextLayer(content: "")
    }

    static func == (lhs: TextInspector, rhs: TextInspector) -> Bool {
        lhs.store === rhs.store && lhs.clip.id == rhs.clip.id
            && lhs.clip.textLayer == rhs.clip.textLayer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
            contentSection
            styleSection
            animationSection
        }
    }

    private var contentSection: some View {
        InspectorSection(.text) {
            TextField(
                localized("inspector.text.content"), text: binding(\.content), axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.roundedBorder)
            Picker(localized("inspector.text.font"), selection: binding(\.fontName)) {
                ForEach(fontOptions, id: \.postScript) { Text($0.name).tag($0.postScript) }
            }
            ColorPicker(
                localized("inspector.text.color"), selection: colorBinding, supportsOpacity: false)
            slider(
                "inspector.text.size", binding(\.fontSize), Self.sizeRange, .points,
                Self.defaults.fontSize)
            slider(
                "inspector.text.positionX", binding(\.positionX), 0...1, .percent,
                Self.defaults.positionX)
            slider(
                "inspector.text.positionY", binding(\.positionY), 0...1, .percent,
                Self.defaults.positionY)
            slider(
                "inspector.text.rotation", binding(\.rotationInDegrees), -180...180, .degrees,
                Self.defaults.rotationInDegrees)
        }
    }

    private var styleSection: some View {
        InspectorSection(.textStyle) {
            PresetGrid(
                items: TextStylePreset.allCases,
                title: Self.title(of:),
                isSelected: { _ in false },
                action: { preset in
                    store.updateTextLayer(of: clip.id, field: "style") { preset.apply(to: &$0) }
                }
            )
            slider(
                "inspector.textStyle.outline", outlineBinding, 0...1, .percent, 0)
            if layer.strokeWidth > 0 {
                ColorPicker(
                    localized("inspector.textStyle.outlineColor"),
                    selection: colorBinding(\.strokeColor, field: "strokeColor"),
                    supportsOpacity: false)
            }
            Toggle(localized("inspector.textStyle.background"), isOn: backgroundToggle)
            if let background = layer.backgroundColor {
                ColorPicker(
                    localized("inspector.textStyle.backgroundColor"),
                    selection: colorBinding(
                        \.backgroundColor, field: "background", fallback: background),
                    supportsOpacity: true
                )
            }
            Toggle(localized("inspector.textStyle.shadow"), isOn: binding(\.hasShadow))
        }
    }

    private var animationSection: some View {
        InspectorSection(.textAnimation) {
            Picker(localized("inspector.textAnimation.in"), selection: binding(\.animation.inKind))
            {
                ForEach(TextAnimationKind.allCases, id: \.self) { Text(Self.title(of: $0)).tag($0) }
            }
            Picker(
                localized("inspector.textAnimation.out"), selection: binding(\.animation.outKind)
            ) {
                ForEach(TextAnimationKind.allCases, id: \.self) { Text(Self.title(of: $0)).tag($0) }
            }
            if !layer.animation.isNone {
                slider(
                    "inspector.textAnimation.duration", binding(\.animation.durationInSeconds),
                    TextAnimation.durationRange, .seconds, Self.noAnimation.durationInSeconds)
            }
        }
    }

    private var outlineBinding: Binding<Double> {
        Binding(
            get: { layer.strokeWidth / TextLayer.maximumStrokeWidth },
            set: { newValue in
                store.updateTextLayer(of: clip.id, field: "strokeWidth") {
                    $0.strokeWidth = newValue * TextLayer.maximumStrokeWidth
                }
            }
        )
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
                    if isOn {
                        $0.backgroundColor = Self.defaultBackgroundColor
                    } else {
                        $0.backgroundColor = nil
                    }
                }
            }
        )
    }

    private var fontOptions: [(name: String, postScript: String)] {
        let isListed = Self.fonts.contains { $0.postScript == layer.fontName }
        guard !isListed else { return Self.fonts }
        return Self.fonts + [(layer.fontName, layer.fontName)]
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<TextLayer, Value>) -> Binding<Value> {
        Binding(
            get: { layer[keyPath: keyPath] },
            set: { newValue in
                store.updateTextLayer(of: clip.id, field: String(describing: keyPath)) {
                    $0[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var colorBinding: Binding<Color> {
        colorBinding(\.color, field: "color")
    }

    private func colorBinding(
        _ keyPath: WritableKeyPath<TextLayer, RGBAColor>, field: String
    ) -> Binding<Color> {
        Binding(
            get: { Self.swiftUIColor(layer[keyPath: keyPath]) },
            set: { newColor in
                store.updateTextLayer(of: clip.id, field: field) {
                    $0[keyPath: keyPath] = Self.rgba(newColor)
                }
            }
        )
    }

    private func colorBinding(
        _ keyPath: WritableKeyPath<TextLayer, RGBAColor?>, field: String, fallback: RGBAColor
    ) -> Binding<Color> {
        Binding(
            get: { Self.swiftUIColor(layer[keyPath: keyPath] ?? fallback) },
            set: { newColor in
                store.updateTextLayer(of: clip.id, field: field) {
                    $0[keyPath: keyPath] = Self.rgba(newColor)
                }
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

    private func slider(
        _ key: String.LocalizationValue,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
        _ unit: ParameterUnit,
        _ defaultValue: Double
    ) -> some View {
        ParameterSlider(
            title: localized(key), value: value, range: range, unit: unit,
            defaultValue: defaultValue)
    }
}

#Preview {
    TextInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.textClip)
        .padding()
}
