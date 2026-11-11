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
        .padding(Design.Spacing.regular)
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
                MediaRow(item: item, thumbnails: thumbnails, onAdd: { onAddToTimeline(item) })
                    .onDrag {
                        library.draggedItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    } preview: {
                        DragPreview(item: item, thumbnails: thumbnails)
                    }
                    .onTapGesture(count: 2) { onAddToTimeline(item) }
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
    let onAdd: () -> Void
    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    private static let thumbnailSize = CGSize(width: 64, height: 40)

    private var addButtonOpacity: Double {
        if isHovering { return 1 }
        return 0
    }

    private var placeholderSymbol: String {
        if item.kind == .audio { return "waveform" }
        return "photo"
    }

    var body: some View {
        HStack {
            thumbnailView
                .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.small))
            VStack(alignment: .leading) {
                Text(item.name).lineLimit(1)
                Text(item.durationInSeconds.clockString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)
            .help(localized("library.addToTimeline"))
            .accessibilityLabel(localized("library.addToTimeline"))
            .opacity(addButtonOpacity)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .task { thumbnail = await thumbnails.thumbnail(for: item) }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: placeholderSymbol)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DragPreview: View {
    let item: MediaItem
    let thumbnails: ThumbnailGenerating
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: Design.Spacing.regular) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 48, height: 32)
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
    @Previewable @State var selection: MediaItem.ID?
    LibraryView(
        library: MediaLibrary(), thumbnails: CachedThumbnailGenerator(),
        selection: $selection, onAddToTimeline: { _ in }
    )
    .frame(width: 280, height: 360)
}
