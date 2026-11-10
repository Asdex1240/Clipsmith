import Foundation
import UniformTypeIdentifiers

enum MediaKind: String, Codable {
    case video, audio, image, text

    init?(url: URL) {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return nil
        }
        if type.conforms(to: .movie) {
            self = .video
        } else if type.conforms(to: .audio) {
            self = .audio
        } else if type.conforms(to: .image) {
            self = .image
        } else {
            return nil
        }
    }
}

struct MediaItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var url: URL
    var kind: MediaKind
    var durationInSeconds: TimeInterval
    /// Displayed size in pixels (rotation applied) of videos and images; nil for audio or when unknown.
    var pixelSize: CGSize?

    var name: String { url.lastPathComponent }
}
