import Foundation

struct FramingKeyframe: Codable, Equatable, Identifiable {
    var id = UUID()
    var timeInSeconds: TimeInterval
    var offsetX: Double
    var easing = Easing.linear

    init(
        id: UUID = UUID(), timeInSeconds: TimeInterval, offsetX: Double, easing: Easing = .linear
    ) {
        self.id = id
        self.timeInSeconds = max(0, timeInSeconds)
        self.offsetX = Highlight.clampedFraming(offsetX)
        self.easing = easing
    }
}

extension FramingKeyframe {
    private enum CodingKeys: String, CodingKey {
        case id, timeInSeconds, offsetX, easing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            timeInSeconds: try container.decode(TimeInterval.self, forKey: .timeInSeconds),
            offsetX: try container.decode(Double.self, forKey: .offsetX),
            easing: try container.decodeIfPresent(Easing.self, forKey: .easing) ?? .linear
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timeInSeconds, forKey: .timeInSeconds)
        try container.encode(offsetX, forKey: .offsetX)
        if !easing.isLinear { try container.encode(easing, forKey: .easing) }
    }
}
