import Foundation

struct Clip: Codable, Identifiable, Equatable {
    static let minimumDurationInSeconds: TimeInterval = 0.1
    static let maximumVolume = 2.0

    var id = UUID()
    var sourceURL: URL?
    var mediaKind: MediaKind
    var startInSeconds: TimeInterval
    var sourceStartInSeconds: TimeInterval
    var sourceEndInSeconds: TimeInterval
    var sourceDurationInSeconds: TimeInterval?
    var volume = 1.0
    var fadeInDurationInSeconds: TimeInterval = 0
    var fadeOutDurationInSeconds: TimeInterval = 0
    var textLayer: TextLayer?
    var fitMode = FitMode.fit
    /// Shift of a visual clip on the canvas, as a fraction of the canvas width and height.
    var offsetX = 0.0
    var offsetY = 0.0

    var displayName: String {
        textLayer?.content ?? sourceURL?.lastPathComponent ?? ""
    }

    var durationInSeconds: TimeInterval { sourceEndInSeconds - sourceStartInSeconds }
    var endInSeconds: TimeInterval { startInSeconds + durationInSeconds }

    init(item: MediaItem, startInSeconds: TimeInterval) {
        self.sourceURL = item.url
        self.mediaKind = item.kind
        self.startInSeconds = startInSeconds
        self.sourceStartInSeconds = 0
        self.sourceEndInSeconds = item.durationInSeconds
        self.sourceDurationInSeconds = item.kind == .image ? nil : item.durationInSeconds
    }

    init(text: TextLayer, startInSeconds: TimeInterval, durationInSeconds: TimeInterval) {
        self.mediaKind = .text
        self.startInSeconds = startInSeconds
        self.sourceStartInSeconds = 0
        self.sourceEndInSeconds = durationInSeconds
        self.textLayer = text
    }

    init(
        sourceURL: URL,
        mediaKind: MediaKind,
        startInSeconds: TimeInterval,
        sourceStartInSeconds: TimeInterval,
        sourceEndInSeconds: TimeInterval,
        sourceDurationInSeconds: TimeInterval? = nil
    ) {
        self.sourceURL = sourceURL
        self.mediaKind = mediaKind
        self.startInSeconds = startInSeconds
        self.sourceStartInSeconds = sourceStartInSeconds
        self.sourceEndInSeconds = sourceEndInSeconds
        self.sourceDurationInSeconds = sourceDurationInSeconds
    }

    func trimmedLeading(to time: TimeInterval, notBefore floor: TimeInterval) -> Clip {
        let lower = max(floor, startInSeconds - sourceStartInSeconds)
        let upper = endInSeconds - Self.minimumDurationInSeconds
        guard lower <= upper else { return self }
        let newStart = min(max(time, lower), upper)
        var trimmed = self
        trimmed.sourceStartInSeconds += newStart - startInSeconds
        trimmed.startInSeconds = newStart
        return trimmed.clampingFades()
    }

    func trimmedTrailing(to time: TimeInterval, notAfter ceiling: TimeInterval) -> Clip {
        let sourceLimit = sourceDurationInSeconds
            .map { startInSeconds + ($0 - sourceStartInSeconds) } ?? .infinity
        let upper = min(ceiling, sourceLimit)
        let lower = startInSeconds + Self.minimumDurationInSeconds
        guard lower <= upper else { return self }
        var trimmed = self
        trimmed.sourceEndInSeconds = sourceStartInSeconds + (min(max(time, lower), upper) - startInSeconds)
        return trimmed.clampingFades()
    }

    func split(at time: TimeInterval) -> (left: Clip, right: Clip)? {
        let earliest = startInSeconds + Self.minimumDurationInSeconds
        let latest = endInSeconds - Self.minimumDurationInSeconds
        guard time >= earliest, time <= latest else { return nil }
        var left = self
        left.sourceEndInSeconds = sourceStartInSeconds + (time - startInSeconds)
        left.fadeOutDurationInSeconds = 0
        var right = self
        right.id = UUID()
        right.startInSeconds = time
        right.sourceStartInSeconds = left.sourceEndInSeconds
        right.fadeInDurationInSeconds = 0
        return (left.clampingFades(), right.clampingFades())
    }

    func settingVolume(_ value: Double) -> Clip {
        var clip = self
        clip.volume = min(max(value, 0), Self.maximumVolume)
        return clip
    }

    func settingFadeIn(_ seconds: TimeInterval) -> Clip {
        var clip = self
        clip.fadeInDurationInSeconds = min(max(seconds, 0), max(0, durationInSeconds - fadeOutDurationInSeconds))
        return clip
    }

    func settingFadeOut(_ seconds: TimeInterval) -> Clip {
        var clip = self
        clip.fadeOutDurationInSeconds = min(max(seconds, 0), max(0, durationInSeconds - fadeInDurationInSeconds))
        return clip
    }

    func clampingFades() -> Clip {
        var clip = self
        clip.fadeInDurationInSeconds = min(fadeInDurationInSeconds, durationInSeconds)
        clip.fadeOutDurationInSeconds = min(fadeOutDurationInSeconds, durationInSeconds - clip.fadeInDurationInSeconds)
        return clip
    }

    func settingOffset(x: Double, y: Double) -> Clip {
        var clip = self
        clip.offsetX = x
        clip.offsetY = y
        return clip
    }

    func settingFitMode(_ mode: FitMode) -> Clip {
        var clip = self
        clip.fitMode = mode
        return clip
    }
}

extension Clip {
    private enum CodingKeys: String, CodingKey {
        case id, sourceURL, mediaKind, startInSeconds, sourceStartInSeconds, sourceEndInSeconds
        case sourceDurationInSeconds, volume, fadeInDurationInSeconds, fadeOutDurationInSeconds
        case textLayer, fitMode, offsetX, offsetY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        mediaKind = try container.decode(MediaKind.self, forKey: .mediaKind)
        startInSeconds = try container.decode(TimeInterval.self, forKey: .startInSeconds)
        sourceStartInSeconds = try container.decode(TimeInterval.self, forKey: .sourceStartInSeconds)
        sourceEndInSeconds = try container.decode(TimeInterval.self, forKey: .sourceEndInSeconds)
        sourceDurationInSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .sourceDurationInSeconds)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        fadeInDurationInSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeInDurationInSeconds) ?? 0
        fadeOutDurationInSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeOutDurationInSeconds) ?? 0
        textLayer = try container.decodeIfPresent(TextLayer.self, forKey: .textLayer)
        fitMode = try container.decodeIfPresent(FitMode.self, forKey: .fitMode) ?? .fit
        offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0
        offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encode(mediaKind, forKey: .mediaKind)
        try container.encode(startInSeconds, forKey: .startInSeconds)
        try container.encode(sourceStartInSeconds, forKey: .sourceStartInSeconds)
        try container.encode(sourceEndInSeconds, forKey: .sourceEndInSeconds)
        try container.encodeIfPresent(sourceDurationInSeconds, forKey: .sourceDurationInSeconds)
        try container.encode(volume, forKey: .volume)
        try container.encode(fadeInDurationInSeconds, forKey: .fadeInDurationInSeconds)
        try container.encode(fadeOutDurationInSeconds, forKey: .fadeOutDurationInSeconds)
        try container.encodeIfPresent(textLayer, forKey: .textLayer)
        try container.encode(fitMode, forKey: .fitMode)
        if offsetX != 0 { try container.encode(offsetX, forKey: .offsetX) }
        if offsetY != 0 { try container.encode(offsetY, forKey: .offsetY) }
    }
}
