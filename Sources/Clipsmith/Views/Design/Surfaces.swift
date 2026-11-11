import SwiftUI

private struct PanelSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor))
        } else {
            content.background(.regularMaterial)
        }
    }
}

private struct CardSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: shape)
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.thinMaterial, in: shape)
        }
    }
}

extension View {
    func panelSurface() -> some View {
        modifier(PanelSurface())
    }

    func cardSurface(cornerRadius: CGFloat = Design.Radius.large) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: Design.Spacing.comfortable) {
        Text("Panel").padding(Design.Spacing.spacious).panelSurface()
        Text("Card").padding(Design.Spacing.spacious).cardSurface()
    }
    .padding(Design.Spacing.roomy)
    .frame(width: 240)
}
