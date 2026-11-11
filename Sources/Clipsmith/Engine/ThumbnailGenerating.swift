import AVFoundation
import AppKit

protocol ThumbnailGenerating {
    func thumbnail(for item: MediaItem) async -> NSImage?
}
