import SwiftUI

struct MediaCard: View {
    let item: MediaItem
    let thumbnails: ThumbnailGenerating
    let isSelected: Bool
    let onAdd: () -> Void
    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    private static let aspectRatio = 16.0 / 9

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.tight) {
            thumbnailView
                .aspectRatio(Self.aspectRatio, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) { durationBadge }
                .overlay(alignment: .topLeading) { kindBadge }
                .overlay(alignment: .topTrailing) { addButton }
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Radius.medium)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .task { thumbnail = await thumbnails.thumbnail(for: item) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(traits)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: item.kind.systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var durationBadge: some View {
        badge(Text(item.durationInSeconds.clockString).monospacedDigit())
            .padding(Design.Spacing.tight)
            .opacity(durationOpacity)
    }

    private var kindBadge: some View {
        badge(Image(systemName: item.kind.systemImage))
            .padding(Design.Spacing.tight)
            .accessibilityHidden(true)
    }

    private func badge(_ content: some View) -> some View {
        content
            .font(.caption2.bold())
            .foregroundStyle(Palette.onMedia)
            .padding(.horizontal, Design.Spacing.compact)
            .padding(.vertical, Design.Spacing.hairline)
            .background(
                Palette.scrim.opacity(Design.Opacity.scrim), in: Capsule())
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Palette.onMedia, Color.accentColor)
        }
        .buttonStyle(.plain)
        .padding(Design.Spacing.tight)
        .opacity(addButtonOpacity)
        .help(localized("library.addToTimeline"))
        .accessibilityLabel(localized("library.addToTimeline"))
    }

    private var durationOpacity: Double {
        guard item.kind != .image else { return 0 }
        return 1
    }

    private var addButtonOpacity: Double {
        if isHovering || isSelected { return 1 }
        return 0
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor }
        return Color.primary.opacity(Design.Opacity.subtleBorder)
    }

    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        return 1
    }

    private var traits: AccessibilityTraits {
        if isSelected { return .isSelected }
        return []
    }
}

#Preview {
    HStack {
        MediaCard(
            item: PreviewFixtures.mediaItem, thumbnails: CachedThumbnailGenerator(),
            isSelected: true, onAdd: {})
        MediaCard(
            item: PreviewFixtures.mediaItem, thumbnails: CachedThumbnailGenerator(),
            isSelected: false, onAdd: {})
    }
    .padding()
    .frame(width: 320)
}
