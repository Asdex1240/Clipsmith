import Foundation

extension Project {
    private static let boundaryToleranceInSeconds: TimeInterval = 1e-6

    @discardableResult
    mutating func removeRanges(
        _ ranges: [Range<TimeInterval>], from clipID: Clip.ID, scope: RippleScope = .ownTracks
    ) -> Int {
        guard let clip = clip(withID: clipID) else { return 0 }
        if scope == .allTracks {
            let ordered = ranges.sorted { $0.lowerBound > $1.lowerBound }
            ordered.forEach { removeTimeRange($0) }
            return ordered.count
        }
        let targets = groupMembers(of: clip.id)
        var removed = 0
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            guard removeRangeFromTargets(range, targets: targets) else { continue }
            removed += 1
        }
        return removed
    }

    private mutating func removeRangeFromTargets(
        _ range: Range<TimeInterval>, targets: Set<Clip.ID>
    ) -> Bool {
        let known = Set(tracks.flatMap(\.clips).map(\.id))
        splitClips(Array(targets), at: range.upperBound)
        splitClips(Array(targets), at: range.lowerBound)
        let middles = tracks.flatMap(\.clips).filter {
            (targets.contains($0.id) || !known.contains($0.id))
                && abs($0.startInSeconds - range.lowerBound) < Self.boundaryToleranceInSeconds
                && abs($0.endInSeconds - range.upperBound) < Self.boundaryToleranceInSeconds
        }
        guard !middles.isEmpty else { return false }
        rippleDeleteClips(Set(middles.map(\.id)))
        return true
    }
}
