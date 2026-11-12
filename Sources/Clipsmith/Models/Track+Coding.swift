import Foundation

extension Track {
    private enum CodingKeys: String, CodingKey {
        case id, role, name, clips, isMuted, isHidden, isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        clips = try container.decodeIfPresent([Clip].self, forKey: .clips) ?? []
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(clips, forKey: .clips)
        if isMuted { try container.encode(true, forKey: .isMuted) }
        if isHidden { try container.encode(true, forKey: .isHidden) }
        if isLocked { try container.encode(true, forKey: .isLocked) }
    }
}

extension Track.Role {
    var canBeMuted: Bool { playsAudio }

    var canBeHidden: Bool {
        switch self {
        case .broll, .main, .text: return true
        case .audio: return false
        }
    }
}
