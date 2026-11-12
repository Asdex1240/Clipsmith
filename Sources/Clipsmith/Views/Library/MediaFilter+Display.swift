import Foundation

extension MediaFilter {
    var titleKey: String {
        switch self {
        case .all: return "library.filter.all"
        case .video: return "library.filter.video"
        case .audio: return "library.filter.audio"
        case .image: return "library.filter.image"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .video: return "film"
        case .audio: return "waveform"
        case .image: return "photo"
        }
    }
}

extension MediaSort {
    var titleKey: String {
        switch self {
        case .added: return "library.sort.added"
        case .name: return "library.sort.name"
        case .duration: return "library.sort.duration"
        }
    }
}
