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
        }
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
        Binding(
            get: { Color(.sRGB, red: layer.color.red, green: layer.color.green, blue: layer.color.blue, opacity: layer.color.alpha) },
            set: { newColor in
                let resolved = NSColor(newColor).usingColorSpace(.sRGB) ?? .white
                store.updateTextLayer(of: clip.id, field: "color") {
                    $0.color = RGBAColor(
                        red: resolved.redComponent, green: resolved.greenComponent,
                        blue: resolved.blueComponent, alpha: resolved.alphaComponent
                    )
                }
            }
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
