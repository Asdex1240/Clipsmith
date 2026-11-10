import Foundation

enum ClipEdge {
    case leading, trailing
}

extension Project {
    var durationInSeconds: TimeInterval {
        tracks.map(\.endInSeconds).max() ?? 0
    }

    func clip(withID id: Clip.ID) -> Clip? {
        tracks.lazy.flatMap(\.clips).first { $0.id == id }
    }

    func track(withRole role: Track.Role) -> Track? {
        tracks.first { $0.role == role }
    }

    func snapPoints(excluding excludedID: Clip.ID?, playhead: TimeInterval) -> [TimeInterval] {
        let clipEdges = tracks.flatMap(\.clips)
            .filter { $0.id != excludedID }
            .flatMap { [$0.startInSeconds, $0.endInSeconds] }
        return [0, playhead] + clipEdges + markers.map(\.timeInSeconds)
    }

    @discardableResult
    mutating func addClip(_ clip: Clip, toTrack trackID: Track.ID) -> Bool {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackID }),
              tracks[trackIndex].role.accepts(clip.mediaKind) else { return false }
        insert(clip, intoTrackAt: trackIndex)
        return true
    }

    @discardableResult
    mutating func moveClip(_ id: Clip.ID, toTrack trackID: Track.ID, startingAt proposedStart: TimeInterval) -> Bool {
        guard let source = location(of: id),
              let targetIndex = tracks.firstIndex(where: { $0.id == trackID }),
              tracks[targetIndex].role.accepts(tracks[source.track].clips[source.clip].mediaKind)
        else { return false }
        let clip = tracks[source.track].clips.remove(at: source.clip)
        insert(clip, intoTrackAt: targetIndex, near: proposedStart)
        return true
    }

    mutating func trimClip(_ id: Clip.ID, edge: ClipEdge, to time: TimeInterval) {
        guard let position = location(of: id) else { return }
        let track = tracks[position.track]
        let clip = track.clips[position.clip]
        switch edge {
        case .leading:
            let floor = track.previousEnd(before: clip)
            tracks[position.track].clips[position.clip] = clip.trimmedLeading(to: time, notBefore: floor)
        case .trailing:
            let ceiling = track.nextStart(after: clip)
            tracks[position.track].clips[position.clip] = clip.trimmedTrailing(to: time, notAfter: ceiling)
        }
    }

    @discardableResult
    mutating func splitClip(_ id: Clip.ID, at time: TimeInterval) -> Bool {
        guard let position = location(of: id),
              let halves = tracks[position.track].clips[position.clip].split(at: time) else { return false }
        tracks[position.track].clips[position.clip] = halves.left
        tracks[position.track].clips.insert(halves.right, at: position.clip + 1)
        return true
    }

    mutating func deleteClip(_ id: Clip.ID) {
        guard let position = location(of: id) else { return }
        tracks[position.track].clips.remove(at: position.clip)
    }

    mutating func rippleDeleteClip(_ id: Clip.ID) {
        guard let position = location(of: id) else { return }
        let removed = tracks[position.track].clips.remove(at: position.clip)
        for index in tracks[position.track].clips.indices
        where tracks[position.track].clips[index].startInSeconds >= removed.startInSeconds {
            tracks[position.track].clips[index].startInSeconds -= removed.durationInSeconds
        }
    }

    /// Adds a marker at `time`, or removes the one already there.
    @discardableResult
    mutating func toggleMarker(at time: TimeInterval) -> Marker.ID? {
        if let existing = markers.firstIndex(where: { abs($0.timeInSeconds - time) <= Marker.toggleToleranceInSeconds }) {
            markers.remove(at: existing)
            return nil
        }
        let marker = Marker(timeInSeconds: max(0, time))
        markers.append(marker)
        markers.sort { $0.timeInSeconds < $1.timeInSeconds }
        return marker.id
    }

    mutating func renameMarker(_ id: Marker.ID, to name: String) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        markers[index].name = name
    }

    mutating func removeMarker(_ id: Marker.ID) {
        markers.removeAll { $0.id == id }
    }

    func location(of id: Clip.ID) -> (track: Int, clip: Int)? {
        for (trackIndex, track) in tracks.enumerated() {
            if let clipIndex = track.clips.firstIndex(where: { $0.id == id }) {
                return (trackIndex, clipIndex)
            }
        }
        return nil
    }

    private mutating func insert(_ clip: Clip, intoTrackAt trackIndex: Int, near proposedStart: TimeInterval? = nil) {
        var placed = clip
        placed.startInSeconds = tracks[trackIndex].nearestFreeStart(
            forDuration: clip.durationInSeconds,
            near: proposedStart ?? clip.startInSeconds,
            excluding: clip.id
        )
        tracks[trackIndex].clips.append(placed)
        tracks[trackIndex].clips.sort { $0.startInSeconds < $1.startInSeconds }
    }
}
