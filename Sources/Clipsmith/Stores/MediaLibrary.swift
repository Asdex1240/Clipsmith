import Foundation
import Observation

@MainActor
@Observable
final class MediaLibrary {
    private(set) var items: [MediaItem] = []
    private(set) var lastErrorMessage: String?
    /// The library item currently being dragged towards the timeline, so lanes can preview the drop.
    var draggedItemID: MediaItem.ID?
    private let loader: MediaLoading

    init(loader: MediaLoading = AVMediaLoader()) {
        self.loader = loader
    }

    func importMedia(from urls: [URL]) async {
        for url in urls where !contains(url) {
            await importSingle(url)
        }
    }

    func replaceItems(_ newItems: [MediaItem]) {
        items = newItems
    }

    func remapSources(_ replacements: [URL: URL]) {
        items = items.map { $0.remapped(replacements) }
    }

    func dismissError() {
        lastErrorMessage = nil
    }

    private func contains(_ url: URL) -> Bool {
        items.contains { $0.url == url }
    }

    private func importSingle(_ url: URL) async {
        do {
            items.append(try await loader.loadItem(from: url))
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
