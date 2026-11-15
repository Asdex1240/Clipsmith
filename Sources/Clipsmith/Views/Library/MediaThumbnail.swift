import SwiftUI

struct MediaThumbnail: View {
    static let aspectRatio = 16.0 / 9

    let item: MediaItem
    let thumbnails: ThumbnailGenerating
    @State private var thumbnail: NSImage?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay { content }
            .clipped()
            .task(id: item.id) { thumbnail = await thumbnails.thumbnail(for: item) }
    }

    @ViewBuilder
    private var content: some View {
        if let thumbnail {
            ZStack {
                Palette.scrim
                Image(nsImage: thumbnail).resizable().scaledToFit()
            }
        } else {
            Image(systemName: item.kind.systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MediaThumbnail(item: PreviewFixtures.mediaItem, thumbnails: CachedThumbnailGenerator())
        .frame(width: 160)
        .padding()
}
