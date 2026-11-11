import AVFoundation
import ImageIO

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
    private static let firstOrientationThatSwapsAxes = 5

    func loadItem(from url: URL) async throws -> MediaItem {
        guard let kind = MediaKind(url: url) else {
            throw ImportError.unsupportedFormat(url)
        }
        let duration = try await loadDuration(of: url, kind: kind)
        let pixelSize = await loadPixelSize(of: url, kind: kind)
        return MediaItem(url: url, kind: kind, durationInSeconds: duration, pixelSize: pixelSize)
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

    private func loadPixelSize(of url: URL, kind: MediaKind) async -> CGSize? {
        switch kind {
        case .video: return await videoSize(of: url)
        case .image: return imageSize(of: url)
        case .audio, .text: return nil
        }
    }

    private func videoSize(of url: URL) async -> CGSize? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (natural, transform) = try? await track.load(.naturalSize, .preferredTransform) else { return nil }
        let oriented = CGRect(origin: .zero, size: natural).applying(transform)
        guard oriented.width > 0, oriented.height > 0 else { return nil }
        return CGSize(width: oriented.width, height: oriented.height)
    }

    private func imageSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0 else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        guard orientation >= Self.firstOrientationThatSwapsAxes else { return CGSize(width: width, height: height) }
        return CGSize(width: height, height: width)
    }
}
