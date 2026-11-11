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
            boundaries.append(
                boundaries[boundaries.count - 1] + fraction * sourceDuration / original.speed)
        }
        guard time >= original.startInSeconds - tolerance,
            boundaries[5] <= original.endInSeconds + tolerance
        else { return false }

        var copy = self
        guard let pieceIDs = copy.splitForSlowMoment(clipID, boundaries: boundaries) else {
            return false
        }
        let end = boundaries[5]
        copy.relayPieces(
            pieceIDs, from: time, factors: SlowMoment.factors(for: slowest), mutesAudio: mutesAudio,
            originalEnd: end)
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
            var isEdge = false
            if index == 5 {
                isEdge = abs(time - current.endInSeconds) < tolerance
            } else if index == 0 {
                isEdge = abs(time - first.startInSeconds) < tolerance
            }
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
        let cursor = repositionPieces(ids, from: start, factors: factors, mutesAudio: mutesAudio)
        let delta = cursor - originalEnd
        guard abs(delta) > SlowMoment.tolerance else { return }
        shiftContent(after: originalEnd, by: delta, excluding: Set(ids))
    }

    private mutating func repositionPieces(
        _ ids: [Clip.ID], from start: TimeInterval, factors: [Double], mutesAudio: Bool
    ) -> TimeInterval {
        var cursor = start
        for (id, factor) in zip(ids, factors) {
            guard let position = location(of: id) else { continue }
            var piece = tracks[position.track].clips[position.clip]
            piece.speed = min(
                max(piece.speed * factor, Clip.speedRange.lowerBound), Clip.speedRange.upperBound)
            if mutesAudio { piece.volume = 0 }
            piece.startInSeconds = cursor
            piece = piece.clampingFades()
            cursor = piece.endInSeconds
            tracks[position.track].clips[position.clip] = piece
        }
        return cursor
    }

    private mutating func shiftContent(
        after originalEnd: TimeInterval, by delta: TimeInterval, excluding moving: Set<Clip.ID>
    ) {
        let tolerance = SlowMoment.tolerance
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
            highlights[index] = highlights[index].shifted(after: originalEnd, by: delta)
        }
    }
}

extension Highlight {
    fileprivate func shifted(after boundary: TimeInterval, by delta: TimeInterval) -> Highlight {
        func moved(_ time: TimeInterval) -> TimeInterval {
            guard time >= boundary else { return time }
            return time + delta
        }
        return Highlight(
            id: id, name: name, startInSeconds: moved(startInSeconds),
            endInSeconds: moved(endInSeconds), framingOffsetX: framingOffsetX, fitMode: fitMode)
    }
}
