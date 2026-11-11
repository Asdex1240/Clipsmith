import Foundation
import UniformTypeIdentifiers

struct MediaItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var url: URL
    var kind: MediaKind
    var durationInSeconds: TimeInterval
    var pixelSize: CGSize?

    var name: String { url.lastPathComponent }
}
