import SwiftUI

struct GuidesOverlay: View {
    let renderSize: CGSize?

    private static let lineWidth = Design.Stroke.hairline
    private static let dash = Design.Stroke.dash

    var body: some View {
        GeometryReader { proxy in
            if let renderSize, renderSize.width > 0, renderSize.height > 0 {
                let frame = CanvasGeometry.fittedRect(of: renderSize, in: proxy.size)
                let guides = SafeAreaGuides(in: frame)
                ZStack {
                    outline(guides.actionSafe)
                    outline(guides.titleSafe)
                    centerLines(guides, in: frame)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func outline(_ rect: CGRect) -> some View {
        Rectangle()
            .stroke(
                Palette.onMedia.opacity(Design.Opacity.outline),
                style: StrokeStyle(lineWidth: Self.lineWidth, dash: Self.dash)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func centerLines(_ guides: SafeAreaGuides, in frame: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: guides.verticalCenter, y: frame.minY))
            path.addLine(to: CGPoint(x: guides.verticalCenter, y: frame.maxY))
            path.move(to: CGPoint(x: frame.minX, y: guides.horizontalCenter))
            path.addLine(to: CGPoint(x: frame.maxX, y: guides.horizontalCenter))
        }
        .stroke(
            Palette.guideCenter.opacity(Design.Opacity.outline),
            style: StrokeStyle(lineWidth: Self.lineWidth, dash: Self.dash))
    }
}

#Preview {
    GuidesOverlay(renderSize: CGSize(width: 1920, height: 1080))
        .background(.black)
        .frame(width: 480, height: 300)
}
