import Foundation

struct Clip: Codable, Identifiable, Equatable {
    static let minimumDurationInSeconds: TimeInterval = 0.1

    var id = UUID()
    var sourceURL: URL
    var mediaKind: MediaKind
    var startInSeconds: TimeInterval
    var sourceStartInSeconds: TimeInterval
    var sourceEndInSeconds: TimeInterval
    var sourceDurationInSeconds: TimeInterval?

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
        return trimmed
    }

    func trimmedTrailing(to time: TimeInterval, notAfter ceiling: TimeInterval) -> Clip {
        let sourceLimit = sourceDurationInSeconds
            .map { startInSeconds + ($0 - sourceStartInSeconds) } ?? .infinity
        let upper = min(ceiling, sourceLimit)
        let lower = startInSeconds + Self.minimumDurationInSeconds
        guard lower <= upper else { return self }
        var trimmed = self
        trimmed.sourceEndInSeconds = sourceStartInSeconds + (min(max(time, lower), upper) - startInSeconds)
        return trimmed
    }

    func split(at time: TimeInterval) -> (left: Clip, right: Clip)? {
        let earliest = startInSeconds + Self.minimumDurationInSeconds
        let latest = endInSeconds - Self.minimumDurationInSeconds
        guard time >= earliest, time <= latest else { return nil }
        var left = self
        left.sourceEndInSeconds = sourceStartInSeconds + (time - startInSeconds)
        var right = self
        right.id = UUID()
        right.startInSeconds = time
        right.sourceStartInSeconds = left.sourceEndInSeconds
        return (left, right)
    }
}
