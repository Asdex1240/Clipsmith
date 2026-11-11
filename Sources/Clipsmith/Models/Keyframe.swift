import Foundation

struct Keyframe: Codable, Equatable, Identifiable {
    var id = UUID()
    var timeInSeconds: TimeInterval
    var state: VisualState
    var easing = Easing.linear
}

extension Keyframe {
    private enum CodingKeys: String, CodingKey {
        case id, timeInSeconds, state, easing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timeInSeconds = try container.decode(TimeInterval.self, forKey: .timeInSeconds)
        state = try container.decode(VisualState.self, forKey: .state)
        easing = try container.decodeIfPresent(Easing.self, forKey: .easing) ?? .linear
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timeInSeconds, forKey: .timeInSeconds)
        try container.encode(state, forKey: .state)
        if !easing.isLinear { try container.encode(easing, forKey: .easing) }
    }
}
