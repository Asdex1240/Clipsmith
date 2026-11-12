import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let library: MediaLibrary
    let thumbnails: ThumbnailGenerating
    @Binding var selection: MediaItem.ID?
    let onAddToTimeline: (MediaItem) -> Void
    @State private var isImporterPresented = false
    @State private var isDropTargeted = false
    @State private var query = MediaQuery()

    private static let importableTypes: [UTType] = [.movie, .audio, .image]
    private static let cardMinimumWidth: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            header
            if !library.items.isEmpty {
                controls
            }
            Divider()
            content
        }
        .overlay { dropOutline }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.importableTypes,
            allowsMultipleSelection: true,
            onCompletion: handleImporterResult
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private var visibleItems: [MediaItem] {
        query.apply(to: library.items)
    }

    private var header: some View {
        HStack {
            Text(localized("panel.library")).font(.headline)
            if !library.items.isEmpty {
                Text(String(format: localized("library.count"), library.items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(localized("library.import")) { isImporterPresented = true }
        }
        .padding(Design.Spacing.regular)
    }

    private var controls: some View {
        VStack(spacing: Design.Spacing.compact) {
            HStack(spacing: Design.Spacing.compact) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(localized("library.search"), text: $query.searchText)
                    .textFieldStyle(.plain)
                sortMenu
            }
            .padding(.horizontal, Design.Spacing.regular)
            .padding(.vertical, Design.Spacing.compact)
            .background(
                Color.primary.opacity(Design.Opacity.chipFill),
                in: RoundedRectangle(cornerRadius: Design.Radius.medium))
            Picker(localized("library.filter.all"), selection: $query.filter) {
                ForEach(MediaFilter.allCases) { filter in
                    Label(
                        localized(String.LocalizationValue(filter.titleKey)),
                        systemImage: filter.systemImage
                    )
                    .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, Design.Spacing.regular)
        .padding(.bottom, Design.Spacing.regular)
    }

    private var sortMenu: some View {
        Menu {
            Picker(localized("library.sort"), selection: $query.sort) {
                ForEach(MediaSort.allCases) { sort in
                    Text(localized(String.LocalizationValue(sort.titleKey))).tag(sort)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(localized("library.sort"))
        .accessibilityLabel(localized("library.sort"))
    }

    @ViewBuilder
    private var content: some View {
        if library.items.isEmpty {
            LibraryEmptyState { isImporterPresented = true }
        } else if visibleItems.isEmpty {
            noResults
        } else {
            grid
        }
    }

    private var noResults: some View {
        VStack(spacing: Design.Spacing.cozy) {
            Text(localized("library.noResults"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localized("library.clearFilters")) { query = MediaQuery() }
        }
        .padding(Design.Spacing.roomy)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: Self.cardMinimumWidth), spacing: Design.Spacing.cozy)
                ],
                spacing: Design.Spacing.cozy
            ) {
                ForEach(visibleItems) { item in
                    card(for: item)
                }
            }
            .padding(Design.Spacing.regular)
        }
    }

    private func card(for item: MediaItem) -> some View {
        MediaCard(
            item: item, thumbnails: thumbnails, isSelected: selection == item.id,
            onAdd: { onAddToTimeline(item) }
        )
        .onTapGesture(count: 2) { onAddToTimeline(item) }
        .onTapGesture { selection = item.id }
        .onDrag {
            library.draggedItemID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        } preview: {
            MediaDragPreview(item: item, thumbnails: thumbnails)
        }
        .contextMenu {
            Button(localized("library.addToTimeline")) { onAddToTimeline(item) }
        }
    }

    @ViewBuilder
    private var dropOutline: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: Design.Radius.large)
                .strokeBorder(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2, dash: [Design.Spacing.regular])
                )
                .padding(Design.Spacing.tight)
                .allowsHitTesting(false)
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

#Preview {
    @Previewable @State var selection: MediaItem.ID?
    LibraryView(
        library: MediaLibrary(), thumbnails: CachedThumbnailGenerator(),
        selection: $selection, onAddToTimeline: { _ in }
    )
    .frame(width: 280, height: 360)
}

#Preview("With media") {
    @Previewable @State var selection: MediaItem.ID?
    let library = MediaLibrary()
    let _ = library.replaceItems([
        PreviewFixtures.mediaItem,
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/music.m4a"), kind: .audio, durationInSeconds: 95),
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"), kind: .image, durationInSeconds: 5),
    ])
    LibraryView(
        library: library, thumbnails: CachedThumbnailGenerator(), selection: $selection,
        onAddToTimeline: { _ in }
    )
    .frame(width: 300, height: 420)
}
