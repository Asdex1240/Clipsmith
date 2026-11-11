import Foundation

struct Highlight: Codable, Identifiable, Equatable {
    static let minimumDurationInSeconds: TimeInterval = 0.5
    static let framingRange = -1.0...1.0

    var id = UUID()
    var name: String
    var startInSeconds: TimeInterval
    var endInSeconds: TimeInterval
    var framingOffsetX = 0.0
    var fitMode = FitMode.fill

    init(
        id: UUID = UUID(), name: String, startInSeconds: TimeInterval, endInSeconds: TimeInterval,
        framingOffsetX: Double = 0, fitMode: FitMode = .fill
    ) {
        let start = max(0, startInSeconds)
        self.id = id
        self.name = name
        self.startInSeconds = start
        self.endInSeconds = max(endInSeconds, start + Self.minimumDurationInSeconds)
        self.framingOffsetX = Self.clampedFraming(framingOffsetX)
        self.fitMode = fitMode
    }

    var durationInSeconds: TimeInterval { endInSeconds - startInSeconds }

    static func clampedFraming(_ value: Double) -> Double {
        min(max(value, framingRange.lowerBound), framingRange.upperBound)
    }
}

extension Highlight {
    private enum CodingKeys: String, CodingKey {
        case id, name, startInSeconds, endInSeconds, framingOffsetX, fitMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            startInSeconds: try container.decode(TimeInterval.self, forKey: .startInSeconds),
            endInSeconds: try container.decode(TimeInterval.self, forKey: .endInSeconds),
            framingOffsetX: try container.decodeIfPresent(Double.self, forKey: .framingOffsetX) ?? 0,
            fitMode: try container.decodeIfPresent(FitMode.self, forKey: .fitMode) ?? .fill
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startInSeconds, forKey: .startInSeconds)
        try container.encode(endInSeconds, forKey: .endInSeconds)
        if framingOffsetX != 0 { try container.encode(framingOffsetX, forKey: .framingOffsetX) }
        if fitMode != .fill { try container.encode(fitMode, forKey: .fitMode) }
    }
}
