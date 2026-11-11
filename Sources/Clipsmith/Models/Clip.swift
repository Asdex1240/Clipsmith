import Foundation

struct Clip: Codable, Identifiable, Equatable {
    static let minimumDurationInSeconds: TimeInterval = 0.1
    static let maximumVolume = 2.0
    static let scaleRange = 0.1...5.0
    static let speedRange = 0.25...4.0

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
    var offsetX = 0.0
    var offsetY = 0.0
    var isAudioDetached = false
    var scale = 1.0
    var rotationInDegrees = 0.0
    var speed = 1.0
    var opacity = 1.0
    var keyframes: [Keyframe] = []
    var transition: ClipTransition?
    var color = ColorAdjustments()
    var crop = CropInsets()
    var groupID: UUID?
    var ducking: ClipDucking?
    var noiseReduction: NoiseReductionLevel?
    var audioOverrideURL: URL?

    var displayName: String {
        textLayer?.content ?? sourceURL?.lastPathComponent ?? ""
    }

    var sourceSpanInSeconds: TimeInterval { sourceEndInSeconds - sourceStartInSeconds }
    var durationInSeconds: TimeInterval { sourceSpanInSeconds / speed }
    var supportsSpeed: Bool { mediaKind == .video || mediaKind == .audio }
    var endInSeconds: TimeInterval { startInSeconds + durationInSeconds }

    init(item: MediaItem, startInSeconds: TimeInterval) {
        self.sourceURL = item.url
        self.mediaKind = item.kind
        self.startInSeconds = startInSeconds
        self.sourceStartInSeconds = 0
        self.sourceEndInSeconds = item.durationInSeconds
        if item.kind == .image {
            self.sourceDurationInSeconds = nil
        } else {
            self.sourceDurationInSeconds = item.durationInSeconds
        }
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
        trimmed.keyframes = shiftingKeyframes(by: startInSeconds - newStart)
        trimmed.sourceStartInSeconds += (newStart - startInSeconds) * speed
        trimmed.startInSeconds = newStart
        return trimmed.clampingFades()
    }

    func trimmedTrailing(to time: TimeInterval, notAfter ceiling: TimeInterval) -> Clip {
        let sourceLimit =
            sourceDurationInSeconds
            .map { startInSeconds + ($0 - sourceStartInSeconds) / speed } ?? .infinity
        let upper = min(ceiling, sourceLimit)
        let lower = startInSeconds + Self.minimumDurationInSeconds
        guard lower <= upper else { return self }
        var trimmed = self
        trimmed.sourceEndInSeconds =
            sourceStartInSeconds + (min(max(time, lower), upper) - startInSeconds) * speed
        return trimmed.clampingFades()
    }

    private func splitKeyframes(at cut: TimeInterval, left: inout Clip, right: inout Clip) {
        let state = visualState(atClipTime: cut)
        left.keyframes =
            keyframes.filter { $0.timeInSeconds < cut } + [
                Keyframe(timeInSeconds: cut, state: state)
            ]
        right.keyframes =
            [Keyframe(timeInSeconds: 0, state: state)]
            + shiftingKeyframes(by: -cut).filter { $0.timeInSeconds > 0 }
    }

    func split(at time: TimeInterval) -> (left: Clip, right: Clip)? {
        let earliest = startInSeconds + Self.minimumDurationInSeconds
        let latest = endInSeconds - Self.minimumDurationInSeconds
        guard time >= earliest, time <= latest else { return nil }
        var left = self
        left.sourceEndInSeconds = sourceStartInSeconds + (time - startInSeconds) * speed
        left.fadeOutDurationInSeconds = 0
        var right = self
        right.id = UUID()
        right.startInSeconds = time
        right.transition = nil
        if isAnimated { splitKeyframes(at: time - startInSeconds, left: &left, right: &right) }
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
        clip.fadeInDurationInSeconds = min(
            max(seconds, 0), max(0, durationInSeconds - fadeOutDurationInSeconds))
        return clip
    }

    func settingFadeOut(_ seconds: TimeInterval) -> Clip {
        var clip = self
        clip.fadeOutDurationInSeconds = min(
            max(seconds, 0), max(0, durationInSeconds - fadeInDurationInSeconds))
        return clip
    }

    func clampingFades() -> Clip {
        var clip = self
        clip.fadeInDurationInSeconds = min(fadeInDurationInSeconds, durationInSeconds)
        clip.fadeOutDurationInSeconds = min(
            fadeOutDurationInSeconds, durationInSeconds - clip.fadeInDurationInSeconds)
        return clip
    }

    func settingTransform(scale: Double, rotationInDegrees: Double) -> Clip {
        var clip = self
        clip.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        clip.rotationInDegrees = rotationInDegrees
        return clip
    }

    func settingSpeed(_ value: Double, notEndingAfter ceiling: TimeInterval = .infinity) -> Clip {
        guard supportsSpeed else { return self }
        var clip = self
        var proposed = min(max(value, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        let room = ceiling - startInSeconds
        if room.isFinite, room > 0 {
            proposed = max(proposed, min(sourceSpanInSeconds / room, Self.speedRange.upperBound))
        }
        clip.speed = proposed
        return clip.clampingFades()
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
        case textLayer, fitMode, offsetX, offsetY, isAudioDetached, scale, rotationInDegrees, speed,
            opacity, keyframes, transition, color, crop, groupID, ducking, noiseReduction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        mediaKind = try container.decode(MediaKind.self, forKey: .mediaKind)
        startInSeconds = try container.decode(TimeInterval.self, forKey: .startInSeconds)
        sourceStartInSeconds = try container.decode(
            TimeInterval.self, forKey: .sourceStartInSeconds)
        sourceEndInSeconds = try container.decode(TimeInterval.self, forKey: .sourceEndInSeconds)
        sourceDurationInSeconds = try container.decodeIfPresent(
            TimeInterval.self, forKey: .sourceDurationInSeconds)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        fadeInDurationInSeconds =
            try container.decodeIfPresent(TimeInterval.self, forKey: .fadeInDurationInSeconds) ?? 0
        fadeOutDurationInSeconds =
            try container.decodeIfPresent(TimeInterval.self, forKey: .fadeOutDurationInSeconds) ?? 0
        textLayer = try container.decodeIfPresent(TextLayer.self, forKey: .textLayer)
        fitMode = try container.decodeIfPresent(FitMode.self, forKey: .fitMode) ?? .fit
        offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0
        offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        isAudioDetached =
            try container.decodeIfPresent(Bool.self, forKey: .isAudioDetached) ?? false
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        rotationInDegrees =
            try container.decodeIfPresent(Double.self, forKey: .rotationInDegrees) ?? 0
        speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        keyframes = try container.decodeIfPresent([Keyframe].self, forKey: .keyframes) ?? []
        transition = try container.decodeIfPresent(ClipTransition.self, forKey: .transition)
        color =
            try container.decodeIfPresent(ColorAdjustments.self, forKey: .color)
            ?? ColorAdjustments()
        crop = try container.decodeIfPresent(CropInsets.self, forKey: .crop) ?? CropInsets()
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        ducking = try container.decodeIfPresent(ClipDucking.self, forKey: .ducking)
        noiseReduction = try container.decodeIfPresent(
            NoiseReductionLevel.self, forKey: .noiseReduction)
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
        if isAudioDetached { try container.encode(isAudioDetached, forKey: .isAudioDetached) }
        if scale != 1 { try container.encode(scale, forKey: .scale) }
        if rotationInDegrees != 0 {
            try container.encode(rotationInDegrees, forKey: .rotationInDegrees)
        }
        if speed != 1 { try container.encode(speed, forKey: .speed) }
        if opacity != 1 { try container.encode(opacity, forKey: .opacity) }
        if !keyframes.isEmpty { try container.encode(keyframes, forKey: .keyframes) }
        try container.encodeIfPresent(transition, forKey: .transition)
        if !color.isIdentity { try container.encode(color, forKey: .color) }
        if !crop.isNone { try container.encode(crop, forKey: .crop) }
        try container.encodeIfPresent(groupID, forKey: .groupID)
        try container.encodeIfPresent(ducking, forKey: .ducking)
        try container.encodeIfPresent(noiseReduction, forKey: .noiseReduction)
    }
}
