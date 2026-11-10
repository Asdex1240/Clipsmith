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
    /// Shift of a visual clip on the canvas, as a fraction of the canvas width and height.
    var offsetX = 0.0
    var offsetY = 0.0
    /// True once the sound of a video clip was extracted onto the audio track, so the video stays silent.
    var isAudioDetached = false
    /// Size of a visual clip relative to its framed size, and its rotation in degrees (clockwise), both around the canvas center.
    var scale = 1.0
    var rotationInDegrees = 0.0
    /// Playback rate of a video or audio clip: 2 plays twice as fast, 0.5 at half speed.
    var speed = 1.0
    /// Fixed opacity of a visual clip; with keyframes the animated value is used instead.
    var opacity = 1.0
    /// Values the visual look moves through over the clip; empty when the clip is not animated.
    var keyframes: [Keyframe] = []
    /// How this clip comes in after the clip right before it; ignored when nothing touches its start.
    var transition: ClipTransition?

    var displayName: String {
        textLayer?.content ?? sourceURL?.lastPathComponent ?? ""
    }

    /// How much of the source the clip plays, regardless of its speed.
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
        trimmed.keyframes = shiftingKeyframes(by: startInSeconds - newStart)
        trimmed.sourceStartInSeconds += (newStart - startInSeconds) * speed
        trimmed.startInSeconds = newStart
        return trimmed.clampingFades()
    }

    func trimmedTrailing(to time: TimeInterval, notAfter ceiling: TimeInterval) -> Clip {
        let sourceLimit = sourceDurationInSeconds
            .map { startInSeconds + ($0 - sourceStartInSeconds) / speed } ?? .infinity
        let upper = min(ceiling, sourceLimit)
        let lower = startInSeconds + Self.minimumDurationInSeconds
        guard lower <= upper else { return self }
        var trimmed = self
        trimmed.sourceEndInSeconds = sourceStartInSeconds + (min(max(time, lower), upper) - startInSeconds) * speed
        return trimmed.clampingFades()
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
        if isAnimated {
            // Each half keeps the animation it had at the cut, so the picture does not jump.
            let cut = time - startInSeconds
            let state = visualState(atClipTime: cut)
            left.keyframes = keyframes.filter { $0.timeInSeconds < cut } + [Keyframe(timeInSeconds: cut, state: state)]
            right.keyframes = [Keyframe(timeInSeconds: 0, state: state)]
                + shiftingKeyframes(by: -cut).filter { $0.timeInSeconds > 0 }
        }
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

    func settingTransform(scale: Double, rotationInDegrees: Double) -> Clip {
        var clip = self
        clip.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        clip.rotationInDegrees = rotationInDegrees
        return clip
    }

    /// Changes the playback rate, keeping the start; the clip grows or shrinks on the timeline.
    /// `ceiling` is the latest time the clip may end at, so it never runs into the next clip.
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
        case textLayer, fitMode, offsetX, offsetY, isAudioDetached, scale, rotationInDegrees, speed, opacity, keyframes, transition
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
        isAudioDetached = try container.decodeIfPresent(Bool.self, forKey: .isAudioDetached) ?? false
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        rotationInDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationInDegrees) ?? 0
        speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        keyframes = try container.decodeIfPresent([Keyframe].self, forKey: .keyframes) ?? []
        transition = try container.decodeIfPresent(ClipTransition.self, forKey: .transition)
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
        if rotationInDegrees != 0 { try container.encode(rotationInDegrees, forKey: .rotationInDegrees) }
        if speed != 1 { try container.encode(speed, forKey: .speed) }
        if opacity != 1 { try container.encode(opacity, forKey: .opacity) }
        if !keyframes.isEmpty { try container.encode(keyframes, forKey: .keyframes) }
        try container.encodeIfPresent(transition, forKey: .transition)
    }
}
