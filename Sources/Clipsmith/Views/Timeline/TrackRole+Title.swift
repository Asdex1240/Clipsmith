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
        return position.count > 1 ? "\(track.role.title) \(position.index + 1)" : track.role.title
    }
}
