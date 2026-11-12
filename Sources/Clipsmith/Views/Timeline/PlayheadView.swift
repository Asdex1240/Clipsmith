import SwiftUI

struct PlayheadView: View {
    let store: ProjectStore
    let pointsPerSecond: Double
    let coordinateSpaceName: String

    private static let lineWidth = Design.Stroke.regular

    var body: some View {
        let size = TimelineMetrics.playheadHeadSize
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Palette.playhead)
                .frame(width: Self.lineWidth)
                .shadow(color: Palette.playhead.opacity(Design.Opacity.handle), radius: 2)
                .allowsHitTesting(false)
            PlayheadHandle()
                .fill(Palette.playhead)
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                        .onChanged { value in
                            store.setPlayhead(near: value.location.x / pointsPerSecond)
                        }
                )
        }
        .frame(width: size.width)
        .offset(
            x: store.playheadInSeconds * pointsPerSecond - size.width / 2 + Self.lineWidth / 2)
    }
}

#Preview {
    PlayheadView(
        store: PreviewFixtures.store(), pointsPerSecond: 40, coordinateSpaceName: "preview"
    )
    .frame(width: 200, height: 100, alignment: .topLeading)
    .coordinateSpace(name: "preview")
}
