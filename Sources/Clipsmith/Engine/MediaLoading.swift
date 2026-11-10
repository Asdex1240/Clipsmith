import AVFoundation

enum ImportError: Error, LocalizedError {
    case unsupportedFormat(URL)
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let url):
            return String(format: localized("error.import.unsupported"), url.lastPathComponent)
        case .unreadable(let url):
            return String(format: localized("error.import.unreadable"), url.lastPathComponent)
        }
    }
}

protocol MediaLoading {
    func loadItem(from url: URL) async throws -> MediaItem
}

struct AVMediaLoader: MediaLoading {
    static let stillImageDurationInSeconds: TimeInterval = 5

    func loadItem(from url: URL) async throws -> MediaItem {
        guard let kind = MediaKind(url: url) else {
            throw ImportError.unsupportedFormat(url)
        }
        let duration = try await loadDuration(of: url, kind: kind)
        return MediaItem(url: url, kind: kind, durationInSeconds: duration)
    }

    private func loadDuration(of url: URL, kind: MediaKind) async throws -> TimeInterval {
        if kind == .image {
            return Self.stillImageDurationInSeconds
        }
        do {
            let duration = try await AVURLAsset(url: url).load(.duration)
            guard duration.isNumeric else { throw ImportError.unreadable(url) }
            return duration.seconds
        } catch {
            throw ImportError.unreadable(url)
        }
    }
}
