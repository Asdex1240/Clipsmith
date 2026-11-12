import SwiftUI

struct DropGhostView: View {
    let preview: DropPreview
    let pointsPerSecond: Double

    var body: some View {
        let tint = preview.tint
        RoundedRectangle(cornerRadius: Design.Radius.medium)
            .fill(tint.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.medium).strokeBorder(
                    tint,
                    style: StrokeStyle(lineWidth: Design.Stroke.regular, dash: Design.Stroke.dash))
            )
            .overlay(alignment: .leading) {
                Label(preview.name, systemImage: preview.iconName)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, Design.Spacing.compact)
            }
            .frame(
                width: max(preview.duration * pointsPerSecond, 24),
                height: TimelineMetrics.laneHeight
            )
            .offset(x: preview.start * pointsPerSecond)
            .allowsHitTesting(false)
    }
}

#Preview {
    DropGhostView(
        preview: DropPreview(
            trackID: UUID(), start: 0, duration: 4, kind: .video, name: "sample.mov", isValid: true
        ),
        pointsPerSecond: 40
    )
    .frame(height: 48)
    .padding()
}
