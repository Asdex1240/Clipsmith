import Foundation

enum SlowMoment {
    static let minimumSourceDurationInSeconds: TimeInterval = 1.5
    static let defaultSourceDurationInSeconds: TimeInterval = 2.5
    static let sourceDurationRange = minimumSourceDurationInSeconds...6.0
    static let factorRange = 0.25...0.8
    static let defaultFactor = 0.4
    static let fractions = [0.1, 0.1, 0.6, 0.1, 0.1]
    static let tolerance: TimeInterval = 1e-6

    static func factors(for slowest: Double) -> [Double] {
        let step = (1 - slowest) / 3
        return [1 - step, 1 - 2 * step, slowest, 1 - 2 * step, 1 - step]
    }

}

extension Project {
    @discardableResult
    mutating func addSlowMoment(
        to clipID: Clip.ID, at time: TimeInterval, sourceDuration: TimeInterval,
        factor: Double = SlowMoment.defaultFactor, mutesAudio: Bool = true
    ) -> Bool {
        let tolerance = SlowMoment.tolerance
        guard let original = clip(withID: clipID), original.supportsSpeed,
            sourceDuration >= SlowMoment.minimumSourceDurationInSeconds
        else { return false }
        let slowest = min(
            max(factor, SlowMoment.factorRange.lowerBound), SlowMoment.factorRange.upperBound)
        var boundaries = [time]
        for fraction in SlowMoment.fractions {
            boundaries.append(boundaries[boundaries.count - 1] + fraction * sourceDuration / original.speed)
        }
        guard time >= original.startInSeconds - tolerance,
            boundaries[5] <= original.endInSeconds + tolerance
        else { return false }

        var copy = self
        guard let pieceIDs = copy.splitForSlowMoment(clipID, boundaries: boundaries) else {
            return false
        }
        let end = boundaries[5]
        copy.relayPieces(pieceIDs, from: time, factors: SlowMoment.factors(for: slowest), mutesAudio: mutesAudio, originalEnd: end)
        self = copy
        return true
    }

    private mutating func splitForSlowMoment(
        _ id: Clip.ID, boundaries: [TimeInterval]
    ) -> [Clip.ID]? {
        let tolerance = SlowMoment.tolerance
        guard let first = clip(withID: id) else { return nil }
        var pieces = [Clip.ID?](repeating: nil, count: 5)
        for index in stride(from: 5, through: 0, by: -1) {
            let time = boundaries[index]
            guard let current = clip(withID: id) else { return nil }
            let isEdge =
                index == 5
                ? abs(time - current.endInSeconds) < tolerance
                : index == 0 && abs(time - first.startInSeconds) < tolerance
            if isEdge {
                if index == 0 { pieces[0] = id }
                continue
            }
            guard splitClip(id, at: time), let position = location(of: id) else { return nil }
            if index == 5 { continue }
            pieces[index] = tracks[position.track].clips[position.clip + 1].id
        }
        guard !pieces.contains(where: { $0 == nil }) else { return nil }
        return pieces.compactMap { $0 }
    }

    private mutating func relayPieces(
        _ ids: [Clip.ID], from start: TimeInterval, factors: [Double], mutesAudio: Bool,
        originalEnd: TimeInterval
    ) {
        let tolerance = SlowMoment.tolerance
        var cursor = start
        for (id, factor) in zip(ids, factors) {
            guard let position = location(of: id) else { continue }
            var piece = tracks[position.track].clips[position.clip]
            piece.speed = min(max(piece.speed * factor, Clip.speedRange.lowerBound), Clip.speedRange.upperBound)
            if mutesAudio { piece.volume = 0 }
            piece.startInSeconds = cursor
            piece = piece.clampingFades()
            cursor = piece.endInSeconds
            tracks[position.track].clips[position.clip] = piece
        }
        let delta = cursor - originalEnd
        guard abs(delta) > tolerance else { return }
        let moving = Set(ids)
        for trackIndex in tracks.indices {
            for clipIndex in tracks[trackIndex].clips.indices {
                let clip = tracks[trackIndex].clips[clipIndex]
                if !moving.contains(clip.id), clip.startInSeconds >= originalEnd - tolerance {
                    tracks[trackIndex].clips[clipIndex].startInSeconds += delta
                }
            }
        }
        for index in markers.indices where markers[index].timeInSeconds >= originalEnd {
            markers[index].timeInSeconds += delta
        }
        for index in highlights.indices {
            let highlight = highlights[index]
            highlights[index] = Highlight(
                id: highlight.id, name: highlight.name,
                startInSeconds: highlight.startInSeconds >= originalEnd ? highlight.startInSeconds + delta : highlight.startInSeconds,
                endInSeconds: highlight.endInSeconds >= originalEnd ? highlight.endInSeconds + delta : highlight.endInSeconds,
                framingOffsetX: highlight.framingOffsetX, fitMode: highlight.fitMode)
        }
    }
}
