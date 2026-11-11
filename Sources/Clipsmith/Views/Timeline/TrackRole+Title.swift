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

extension Project {
    func title(of track: Track) -> String {
        if let name = track.name { return name }
        let position = ordinal(of: track)
        guard position.count > 1 else { return track.role.title }
        return "\(track.role.title) \(position.index + 1)"
    }
}
