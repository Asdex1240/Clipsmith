import Foundation

extension Project {
    private static let removalToleranceInSeconds: TimeInterval = 1e-6

    mutating func removeTimeRange(_ range: Range<TimeInterval>) {
        let length = range.upperBound - range.lowerBound
        guard length > 0 else { return }
        var newGroups: [UUID: UUID] = [:]
        for trackIndex in tracks.indices {
            tracks[trackIndex].clips = tracks[trackIndex].clips.flatMap {
                Self.survivors(of: $0, removing: range, newGroups: &newGroups)
            }
        }
        markers = markers.compactMap { marker in
            var moved = marker
            moved.timeInSeconds = Self.timeAfterRemoving(range, from: marker.timeInSeconds)
            let isInside =
                marker.timeInSeconds > range.lowerBound && marker.timeInSeconds < range.upperBound
            guard !isInside else { return nil }
            return moved
        }
        for index in highlights.indices {
            let highlight = highlights[index]
            highlights[index] = Highlight(
                id: highlight.id, name: highlight.name,
                startInSeconds: Self.timeAfterRemoving(range, from: highlight.startInSeconds),
                endInSeconds: Self.timeAfterRemoving(range, from: highlight.endInSeconds),
                framingOffsetX: highlight.framingOffsetX, fitMode: highlight.fitMode)
        }
    }

    private static func timeAfterRemoving(
        _ range: Range<TimeInterval>, from time: TimeInterval
    )
        -> TimeInterval
    {
        if time >= range.upperBound { return time - (range.upperBound - range.lowerBound) }
        if time > range.lowerBound { return range.lowerBound }
        return time
    }

    private static func survivors(
        of clip: Clip, removing range: Range<TimeInterval>, newGroups: inout [UUID: UUID]
    ) -> [Clip] {
        let tolerance = removalToleranceInSeconds
        let length = range.upperBound - range.lowerBound
        if clip.endInSeconds <= range.lowerBound + tolerance { return [clip] }
        if clip.startInSeconds >= range.upperBound - tolerance {
            var moved = clip
            moved.startInSeconds -= length
            return [moved]
        }
        if clip.startInSeconds >= range.lowerBound - tolerance,
            clip.endInSeconds <= range.upperBound + tolerance
        {
            return []
        }
        var pieces: [Clip] = []
        if let leading = leadingPiece(of: clip, removing: range) { pieces.append(leading) }
        guard var trailing = trailingPiece(of: clip, removing: range) else { return pieces }
        if !pieces.isEmpty, let group = clip.groupID {
            let replacement = newGroups[group] ?? UUID()
            newGroups[group] = replacement
            trailing.groupID = replacement
        }
        pieces.append(trailing)
        return pieces
    }

    private static func leadingPiece(of clip: Clip, removing range: Range<TimeInterval>) -> Clip? {
        guard clip.startInSeconds < range.lowerBound,
            range.lowerBound - clip.startInSeconds >= Clip.minimumDurationInSeconds
        else { return nil }
        return clip.trimmedTrailing(to: range.lowerBound, notAfter: range.upperBound)
    }

    private static func trailingPiece(of clip: Clip, removing range: Range<TimeInterval>) -> Clip? {
        guard clip.endInSeconds - range.upperBound >= Clip.minimumDurationInSeconds else {
            return nil
        }
        var trailing = clip.trimmedLeading(to: range.upperBound, notBefore: 0)
        if let halves = clip.split(at: range.upperBound) { trailing = halves.right }
        trailing.startInSeconds = range.lowerBound
        return trailing
    }
}
