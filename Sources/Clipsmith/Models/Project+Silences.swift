import Foundation

extension Project {
    private static let boundaryToleranceInSeconds: TimeInterval = 1e-6

    @discardableResult
    mutating func removeRanges(
        _ ranges: [Range<TimeInterval>], from clipID: Clip.ID, syncingAllTracks: Bool = false
    ) -> Int {
        guard let clip = clip(withID: clipID) else { return 0 }
        if syncingAllTracks {
            let ordered = ranges.sorted { $0.lowerBound > $1.lowerBound }
            ordered.forEach { removeTimeRange($0) }
            return ordered.count
        }
        var targets: Set<Clip.ID> = [clipID]
        if let group = clip.groupID {
            targets.formUnion(tracks.flatMap(\.clips).filter { $0.groupID == group }.map(\.id))
        }
        var removed = 0
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            let known = Set(tracks.flatMap(\.clips).map(\.id))
            splitClips(Array(targets), at: range.upperBound)
            splitClips(Array(targets), at: range.lowerBound)
            let middles = tracks.flatMap(\.clips).filter {
                (targets.contains($0.id) || !known.contains($0.id))
                    && abs($0.startInSeconds - range.lowerBound) < Self.boundaryToleranceInSeconds
                    && abs($0.endInSeconds - range.upperBound) < Self.boundaryToleranceInSeconds
            }
            guard !middles.isEmpty else { continue }
            rippleDeleteClips(Set(middles.map(\.id)))
            removed += 1
        }
        return removed
    }
}
