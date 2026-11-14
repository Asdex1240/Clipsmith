import SwiftUI

struct TitleTemplateCard: View {
    let template: TitleTemplate
    let onAdd: () -> Void

    private static let aspectRatio = 16.0 / 9
    private static let previewScale = 0.11
    private static let outlineOffsets: [CGSize] = [
        CGSize(width: 1, height: 1), CGSize(width: -1, height: 1),
        CGSize(width: 1, height: -1), CGSize(width: -1, height: -1),
    ]

    private var sample: String { localized(String.LocalizationValue(template.sampleKey)) }
    private var layer: TextLayer { template.layer(content: sample) }

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: Design.Spacing.tight) {
                preview
                    .aspectRatio(Self.aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Design.Radius.medium))
                Text(localized(String.LocalizationValue(template.titleKey)))
                    .font(.caption)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(localized("title.add.help"))
        .accessibilityLabel(localized(String.LocalizationValue(template.titleKey)))
    }

    private var preview: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(Color.black.opacity(Design.Opacity.titleBackdrop))
                styledText(size: proxy.size)
                    .position(
                        x: proxy.size.width * layer.positionX,
                        y: proxy.size.height * layer.positionY)
            }
        }
    }

    private func styledText(size: CGSize) -> some View {
        let font = Font.custom(layer.fontName, size: layer.fontSize * Self.previewScale)
        return outlined(Text(layer.content).font(font), color: layer.strokeColor)
            .foregroundStyle(color(of: layer.color))
            .padding(.horizontal, boxPadding)
            .padding(.vertical, boxPadding / 2)
            .background(boxFill, in: RoundedRectangle(cornerRadius: Design.Radius.small))
            .shadow(radius: shadowRadius)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: size.width * 0.9)
    }

    @ViewBuilder
    private func outlined(_ text: some View, color: RGBAColor) -> some View {
        if layer.strokeWidth > 0 {
            ZStack {
                ForEach(Self.outlineOffsets.indices, id: \.self) { index in
                    text.foregroundStyle(self.color(of: color)).offset(Self.outlineOffsets[index])
                }
                text
            }
        } else {
            text
        }
    }

    private var boxFill: Color {
        guard let background = layer.backgroundColor else { return .clear }
        return color(of: background)
    }

    private var boxPadding: CGFloat {
        guard layer.backgroundColor != nil else { return 0 }
        return Design.Spacing.compact
    }

    private var shadowRadius: CGFloat {
        guard layer.hasShadow else { return 0 }
        return 1.5
    }

    private func color(of tone: RGBAColor) -> Color {
        Color(.sRGB, red: tone.red, green: tone.green, blue: tone.blue, opacity: tone.alpha)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))]) {
        ForEach(TitleTemplate.allCases) { template in
            TitleTemplateCard(template: template, onAdd: {})
        }
    }
    .padding()
    .frame(width: 320)
}
