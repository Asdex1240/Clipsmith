import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let library: MediaLibrary
    let thumbnails: ThumbnailGenerating
    @Binding var selection: MediaItem.ID?
    let onAddToTimeline: (MediaItem) -> Void
    @State private var isImporterPresented = false

    private static let importableTypes: [UTType] = [.movie, .audio, .image]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.importableTypes,
            allowsMultipleSelection: true,
            onCompletion: handleImporterResult
        )
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }

    private var header: some View {
        HStack {
            Text(localized("panel.library")).font(.headline)
            Spacer()
            Button(localized("library.import")) { isImporterPresented = true }
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        if library.items.isEmpty {
            ZStack {
                Rectangle().fill(.background.secondary)
                Text(localized("library.empty"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        } else {
            List(library.items, selection: $selection) { item in
                MediaRow(item: item, thumbnails: thumbnails)
                    .draggable(item.id.uuidString)
                    .contextMenu {
                        Button(localized("library.addToTimeline")) { onAddToTimeline(item) }
                    }
            }
        }
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        Task { await library.importMedia(from: urls) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in await library.importMedia(from: [url]) }
            }
        }
        return !providers.isEmpty
    }
}

private struct MediaRow: View {
    let item: MediaItem
    let thumbnails: ThumbnailGenerating
    @State private var thumbnail: NSImage?

    private static let thumbnailSize = CGSize(width: 64, height: 40)

    var body: some View {
        HStack {
            thumbnailView
                .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading) {
                Text(item.name).lineLimit(1)
                Text(item.durationInSeconds.clockString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { thumbnail = await thumbnails.thumbnail(for: item) }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: item.kind == .audio ? "waveform" : "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
