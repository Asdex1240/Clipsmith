import SwiftUI

struct TrackHeaderView: View {
    let store: ProjectStore
    let track: Track

    var body: some View {
        HStack(spacing: Design.Spacing.compact) {
            Image(systemName: track.role.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: Design.Size.sectionIcon)
                .accessibilityHidden(true)
            Text(store.project.title(of: track))
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Design.Spacing.regular)
        .frame(width: TimelineMetrics.trackHeaderWidth, height: TimelineMetrics.laneHeight)
        .background(
            Color.primary.opacity(Design.Opacity.chipFill),
            in: RoundedRectangle(cornerRadius: Design.Radius.medium)
        )
        .contextMenu { menu }
    }

    @ViewBuilder
    private var menu: some View {
        Button(localized("track.moveUp")) { store.moveTrack(track.id, direction: .up) }
            .disabled(!store.project.canMoveTrack(track.id, direction: .up))
        Button(localized("track.moveDown")) { store.moveTrack(track.id, direction: .down) }
            .disabled(!store.project.canMoveTrack(track.id, direction: .down))
        Divider()
        Button(localized("track.remove"), role: .destructive) { store.removeTrack(track.id) }
            .disabled(!store.project.canRemoveTrack(track.id))
    }
}

#Preview {
    let store = PreviewFixtures.store()
    if let track = store.project.track(withRole: .main) {
        TrackHeaderView(store: store, track: track)
            .padding()
    }
}
