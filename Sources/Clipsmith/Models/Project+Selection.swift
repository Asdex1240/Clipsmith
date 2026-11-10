import Foundation

/// Edits that act on several clips at once, and on clips grouped together.
extension Project {
    /// The clip together with every clip grouped with it.
    func groupMembers(of id: Clip.ID) -> Set<Clip.ID> {
        guard let clip = clip(withID: id) else { return [] }
        guard let group = clip.groupID else { return [id] }
        return Set(tracks.flatMap(\.clips).filter { $0.groupID == group }.map(\.id))
    }

    /// `ids` plus the rest of every group they touch.
    func expandedToGroups(_ ids: Set<Clip.ID>) -> Set<Clip.ID> {
        ids.reduce(into: Set<Clip.ID>()) { result, id in result.formUnion(groupMembers(of: id)) }
    }

    var allClipIDs: Set<Clip.ID> {
        Set(tracks.flatMap(\.clips).map(\.id))
    }

    func snapPoints(excluding excludedIDs: Set<Clip.ID>, playhead: TimeInterval) -> [TimeInterval] {
        let clipEdges = tracks.flatMap(\.clips)
            .filter { !excludedIDs.contains($0.id) }
            .flatMap { [$0.startInSeconds, $0.endInSeconds] }
        return [0, playhead] + clipEdges + markers.map(\.timeInSeconds)
    }

    /// Moves clips together by `delta` seconds, as far as they can go without running into other clips or before zero.
    @discardableResult
    mutating func moveClips(_ ids: Set<Clip.ID>, by delta: TimeInterval) -> TimeInterval {
        var lowest = -Double.infinity
        var highest = Double.infinity
        for track in tracks {
            let moving = track.clips.filter { ids.contains($0.id) }
            let staying = track.clips.filter { !ids.contains($0.id) }
            for clip in moving {
                let previousEnd = staying
                    .filter { $0.endInSeconds <= clip.startInSeconds + Track.overlapToleranceInSeconds }
                    .map(\.endInSeconds).max() ?? 0
                let nextStart = staying
                    .filter { $0.startInSeconds >= clip.endInSeconds - Track.overlapToleranceInSeconds }
                    .map(\.startInSeconds).min() ?? .infinity
                lowest = max(lowest, previousEnd - clip.startInSeconds)
                highest = min(highest, nextStart - clip.endInSeconds)
            }
        }
        guard lowest.isFinite || highest.isFinite else { return 0 }
        let allowed = lowest <= highest ? min(max(delta, lowest), highest) : 0
        guard allowed != 0 else { return 0 }
        for trackIndex in tracks.indices {
            for clipIndex in tracks[trackIndex].clips.indices where ids.contains(tracks[trackIndex].clips[clipIndex].id) {
                tracks[trackIndex].clips[clipIndex].startInSeconds += allowed
            }
            tracks[trackIndex].clips.sort { $0.startInSeconds < $1.startInSeconds }
        }
        return allowed
    }

    mutating func deleteClips(_ ids: Set<Clip.ID>) {
        for trackIndex in tracks.indices {
            tracks[trackIndex].clips.removeAll { ids.contains($0.id) }
        }
    }

    /// Deletes clips and closes each gap; the latest ones go first so earlier ones keep their place.
    mutating func rippleDeleteClips(_ ids: Set<Clip.ID>) {
        let ordered = tracks.flatMap(\.clips).filter { ids.contains($0.id) }.sorted { $0.startInSeconds > $1.startInSeconds }
        ordered.forEach { rippleDeleteClip($0.id) }
    }

    /// Splits each clip at `time`. The new second halves of a group form a group of their own.
    mutating func splitClips(_ ids: [Clip.ID], at time: TimeInterval) {
        var secondHalfGroups: [UUID: UUID] = [:]
        for id in ids {
            guard let before = location(of: id), splitClip(id, at: time) else { continue }
            guard let group = tracks[before.track].clips[before.clip].groupID else { continue }
            let newGroup = secondHalfGroups[group] ?? UUID()
            secondHalfGroups[group] = newGroup
            tracks[before.track].clips[before.clip + 1].groupID = newGroup
        }
    }

    /// Groups the clips so they are selected and moved together; false when there are fewer than two.
    @discardableResult
    mutating func group(_ ids: Set<Clip.ID>) -> Bool {
        guard ids.count >= 2 else { return false }
        let group = UUID()
        for trackIndex in tracks.indices {
            for clipIndex in tracks[trackIndex].clips.indices where ids.contains(tracks[trackIndex].clips[clipIndex].id) {
                tracks[trackIndex].clips[clipIndex].groupID = group
            }
        }
        return true
    }

    /// Breaks up every group that any of the clips belongs to.
    mutating func ungroup(_ ids: Set<Clip.ID>) {
        let groups = Set(tracks.flatMap(\.clips).filter { ids.contains($0.id) }.compactMap(\.groupID))
        for trackIndex in tracks.indices {
            for clipIndex in tracks[trackIndex].clips.indices {
                if let group = tracks[trackIndex].clips[clipIndex].groupID, groups.contains(group) {
                    tracks[trackIndex].clips[clipIndex].groupID = nil
                }
            }
        }
    }
}
