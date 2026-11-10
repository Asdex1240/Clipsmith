extension Track.Role {
    var title: String {
        switch self {
        case .broll: return localized("track.broll")
        case .main: return localized("track.main")
        case .audio: return localized("track.audio")
        case .text: return localized("track.text")
        }
    }
}
