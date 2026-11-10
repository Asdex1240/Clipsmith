import Foundation

extension Track.Role {
    /// Tracks of the same kind can be reordered among themselves.
    enum Family {
        case video, audio, text
    }

    var family: Family {
        switch self {
        case .main, .broll: return .video
        case .audio: return .audio
        case .text: return .text
        }
    }
}

extension Project {
    /// The tracks that draw pictures, from the one on top to the one at the bottom of the stack.
    var videoTracksTopFirst: [Track] {
        tracks.filter { $0.role.family == .video }
    }

    func tracks(withRole role: Track.Role) -> [Track] {
        tracks.filter { $0.role == role }
    }

    /// Where `track` sits among the tracks of its role, from the top, and how many there are.
    func ordinal(of track: Track) -> (index: Int, count: Int) {
        let same = tracks(withRole: track.role)
        return (same.firstIndex { $0.id == track.id } ?? 0, same.count)
    }

    /// The first track of the role that is free during the given time, or the first one if all are busy.
    func trackWithRoom(role: Track.Role, start: TimeInterval, duration: TimeInterval) -> Track? {
        let candidates = tracks(withRole: role)
        return candidates.first { track in
            !track.clips.contains { other in
                start < other.endInSeconds - Track.overlapToleranceInSeconds
                    && start + duration > other.startInSeconds + Track.overlapToleranceInSeconds
            }
        } ?? candidates.first
    }

    /// The main track and at least one track of every other kind stay, so there is always somewhere to put a clip.
    func canRemoveTrack(_ id: Track.ID) -> Bool {
        guard let track = tracks.first(where: { $0.id == id }) else { return false }
        return track.role != .main && tracks(withRole: track.role).count > 1
    }

    func canMoveTrack(_ id: Track.ID, up: Bool) -> Bool {
        neighbour(of: id, up: up) != nil
    }

    /// Adds an empty track: video above the others, audio below them, text at the top.
    @discardableResult
    mutating func addTrack(role: Track.Role) -> Track.ID? {
        guard role != .main else { return nil }
        let track = Track(role: role)
        switch role {
        case .broll:
            tracks.insert(track, at: tracks.firstIndex { $0.role.family == .video } ?? 0)
        case .audio:
            tracks.insert(track, at: (tracks.lastIndex { $0.role == .audio } ?? tracks.count - 1) + 1)
        case .text:
            tracks.insert(track, at: tracks.firstIndex { $0.role == .text } ?? 0)
        case .main:
            return nil
        }
        return track.id
    }

    /// Removes a track together with the clips on it.
    mutating func removeTrack(_ id: Track.ID) {
        guard canRemoveTrack(id) else { return }
        tracks.removeAll { $0.id == id }
    }

    /// Swaps a track with the nearest one of its kind above or below it.
    mutating func moveTrack(_ id: Track.ID, up: Bool) {
        guard let index = tracks.firstIndex(where: { $0.id == id }), let other = neighbour(of: id, up: up) else { return }
        tracks.swapAt(index, other)
    }

    private func neighbour(of id: Track.ID, up: Bool) -> Int? {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return nil }
        let family = tracks[index].role.family
        let candidates = up ? Array(tracks.indices.filter { $0 < index }.reversed()) : tracks.indices.filter { $0 > index }
        return candidates.first { tracks[$0].role.family == family }
    }

    mutating func renameTrack(_ id: Track.ID, to name: String) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tracks[index].name = trimmed.isEmpty ? nil : trimmed
    }

    /// The audio track that is free during `clip`, for the sound taken out of a video.
    func audioTrackWithRoom(for clip: Clip) -> Track? {
        let candidates = tracks(withRole: .audio)
        return candidates.first { track in
            !track.clips.contains { other in
                clip.startInSeconds < other.endInSeconds - Track.overlapToleranceInSeconds
                    && clip.endInSeconds > other.startInSeconds + Track.overlapToleranceInSeconds
            }
        }
    }
}
