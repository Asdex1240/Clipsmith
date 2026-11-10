import AVFoundation
import AppKit

protocol ThumbnailGenerating {
    func thumbnail(for item: MediaItem) async -> NSImage?
}

final class CachedThumbnailGenerator: ThumbnailGenerating {
    private static let maximumSide: CGFloat = 320
    private let cache = NSCache<NSUUID, NSImage>()

    func thumbnail(for item: MediaItem) async -> NSImage? {
        let key = item.id as NSUUID
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = await render(item) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    private func render(_ item: MediaItem) async -> NSImage? {
        switch item.kind {
        case .image: return NSImage(contentsOf: item.url)
        case .video: return await renderVideoFrame(of: item)
        case .audio: return nil
        }
    }

    private func renderVideoFrame(of item: MediaItem) async -> NSImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: item.url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: Self.maximumSide, height: Self.maximumSide)
        let time = CMTime(seconds: item.durationInSeconds / 2, preferredTimescale: 600)
        guard let cgImage = try? await generator.image(at: time).image else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
