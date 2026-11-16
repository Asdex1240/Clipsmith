import Foundation
import Observation

@MainActor
@Observable
final class MediaLibrary {
    private(set) var items: [MediaItem] = []
    private(set) var lastErrorMessage: String?
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

    @discardableResult
    func removeItem(_ id: MediaItem.ID) -> Int? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        items.remove(at: index)
        return index
    }

    func insert(_ item: MediaItem, at index: Int) {
        guard !contains(item.url) else { return }
        items.insert(item, at: min(index, items.count))
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
