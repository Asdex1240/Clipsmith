import CoreGraphics
import Foundation
import ImageIO

struct ImageFilmstripGenerator: FilmstripGenerating {
    static let durationInSeconds: TimeInterval = 1

    func filmstrip(for url: URL) async -> Filmstrip? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: AVFilmstripGenerator.frameHeightInPixels * 4,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return Filmstrip(frames: [image], durationInSeconds: Self.durationInSeconds)
    }
}
