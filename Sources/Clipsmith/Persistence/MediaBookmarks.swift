import Foundation

enum MediaBookmarks {
    struct Resolution: Equatable {
        let url: URL
        let exists: Bool
    }

    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(original: URL, bookmark: Data?) -> Resolution {
        if let moved = resolveBookmark(bookmark), fileExists(moved), !isSameFile(moved, original) {
            _ = moved.startAccessingSecurityScopedResource()
            return Resolution(url: moved, exists: true)
        }
        if fileExists(original) {
            _ = original.startAccessingSecurityScopedResource()
            return Resolution(url: original, exists: true)
        }
        return Resolution(url: original, exists: false)
    }

    private static func resolveBookmark(_ bookmark: Data?) -> URL? {
        guard let bookmark else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private static func isSameFile(_ first: URL, _ second: URL) -> Bool {
        first.resolvingSymlinksInPath().path == second.resolvingSymlinksInPath().path
    }

    private static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
