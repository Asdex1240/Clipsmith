import SwiftUI

struct MediaDragPreview: View {
    let item: MediaItem
    let thumbnails: ThumbnailGenerating
    @State private var thumbnail: NSImage?

    private static let size = CGSize(width: 48, height: 32)

    var body: some View {
        HStack(spacing: Design.Spacing.regular) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius.small))
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).lineLimit(1).font(.caption.bold())
                Text(item.durationInSeconds.clockString).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(Design.Spacing.compact)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.large))
        .task { thumbnail = await thumbnails.thumbnail(for: item) }
    }
}

#Preview {
    MediaDragPreview(item: PreviewFixtures.mediaItem, thumbnails: CachedThumbnailGenerator())
        .padding()
}
