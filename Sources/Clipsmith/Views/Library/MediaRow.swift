import SwiftUI

struct MediaRow: View {
    private static let thumbnailWidth: CGFloat = 64

    let item: MediaItem
    let thumbnails: ThumbnailGenerating
    let isSelected: Bool
    let onAdd: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Design.Spacing.regular) {
            MediaThumbnail(item: item, thumbnails: thumbnails)
                .frame(width: Self.thumbnailWidth)
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.small))
            details
            Spacer(minLength: 0)
            addButton
        }
        .padding(Design.Spacing.tight)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: Design.Radius.medium))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .motion(value: isHovering)
        .motion(value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(traits)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.hairline) {
            Text(item.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: Design.Spacing.tight) {
                Image(systemName: item.kind.systemImage).accessibilityHidden(true)
                if item.kind != .image {
                    Text(item.durationInSeconds.clockString).monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Palette.onMedia, Color.accentColor)
                .minimumHitTarget()
        }
        .buttonStyle(.plain)
        .opacity(addButtonOpacity)
        .help(localized("library.addToTimeline"))
        .accessibilityLabel(localized("library.addToTimeline"))
    }

    private var addButtonOpacity: Double {
        if isHovering || isSelected { return 1 }
        return 0
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(Design.Opacity.selectedChipFill) }
        if isHovering { return Color.primary.opacity(Design.Opacity.chipFill) }
        return .clear
    }

    private var traits: AccessibilityTraits {
        if isSelected { return .isSelected }
        return []
    }
}

#Preview {
    VStack {
        MediaRow(
            item: PreviewFixtures.mediaItem, thumbnails: CachedThumbnailGenerator(),
            isSelected: true, onAdd: {})
        MediaRow(
            item: PreviewFixtures.mediaItem, thumbnails: CachedThumbnailGenerator(),
            isSelected: false, onAdd: {})
    }
    .padding()
    .frame(width: 280)
}
