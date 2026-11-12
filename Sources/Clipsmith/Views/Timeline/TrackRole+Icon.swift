import Foundation

extension Track.Role {
    var systemImage: String {
        switch self {
        case .broll, .main: return "film"
        case .audio: return "speaker.wave.2"
        case .text: return "textformat"
        }
    }
}

extension MediaKind {
    var systemImage: String {
        switch self {
        case .video: return "film"
        case .image: return "photo"
        case .audio: return "waveform"
        case .text: return "textformat"
        }
    }
}
