import Foundation

enum MediaFilter: String, CaseIterable, Identifiable {
    case all, video, audio, image

    var id: String { rawValue }

    func accepts(_ kind: MediaKind) -> Bool {
        switch self {
        case .all: return true
        case .video: return kind == .video
        case .audio: return kind == .audio
        case .image: return kind == .image
        }
    }
}
