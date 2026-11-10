import Foundation
import Observation

@MainActor
@Observable
final class MediaLibrary {
    private(set) var items: [MediaItem] = []
    private(set) var lastErrorMessage: String?
    private let loader: MediaLoading

    init(loader: MediaLoading = AVMediaLoader()) {
        self.loader = loader
    }

    func importMedia(from urls: [URL]) async {
        for url in urls where !contains(url) {
            await importSingle(url)
        }
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
