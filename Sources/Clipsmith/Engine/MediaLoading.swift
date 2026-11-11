import AVFoundation
import ImageIO

protocol MediaLoading {
    func loadItem(from url: URL) async throws -> MediaItem
}
