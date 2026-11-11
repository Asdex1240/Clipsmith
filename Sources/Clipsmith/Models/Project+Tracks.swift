import Foundation

enum TrackMoveDirection {
    case up, down
}

extension Track.Role {
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
    var videoTracksTopFirst: [Track] {
        tracks.filter { $0.role.family == .video }
    }

    func tracks(withRole role: Track.Role) -> [Track] {
        tracks.filter { $0.role == role }
    }

    func ordinal(of track: Track) -> (index: Int, count: Int) {
        let same = tracks(withRole: track.role)
        return (same.firstIndex { $0.id == track.id } ?? 0, same.count)
    }

    func trackWithRoom(role: Track.Role, start: TimeInterval, duration: TimeInterval) -> Track? {
        let candidates = tracks(withRole: role)
        return candidates.first { $0.isFree(from: start, to: start + duration) } ?? candidates.first
    }

    func canRemoveTrack(_ id: Track.ID) -> Bool {
        guard let track = tracks.first(where: { $0.id == id }) else { return false }
        return track.role != .main && tracks(withRole: track.role).count > 1
    }

    func canMoveTrack(_ id: Track.ID, direction: TrackMoveDirection) -> Bool {
        neighbour(of: id, direction: direction) != nil
    }

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

    mutating func removeTrack(_ id: Track.ID) {
        guard canRemoveTrack(id) else { return }
        tracks.removeAll { $0.id == id }
    }

    mutating func moveTrack(_ id: Track.ID, direction: TrackMoveDirection) {
        guard let index = tracks.firstIndex(where: { $0.id == id }),
              let other = neighbour(of: id, direction: direction) else { return }
        tracks.swapAt(index, other)
    }

    private func neighbour(of id: Track.ID, direction: TrackMoveDirection) -> Int? {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return nil }
        let family = tracks[index].role.family
        let candidates: [Int]
        switch direction {
        case .up: candidates = tracks.indices.filter { $0 < index }.reversed()
        case .down: candidates = tracks.indices.filter { $0 > index }
        }
        return candidates.first { tracks[$0].role.family == family }
    }

    mutating func renameTrack(_ id: Track.ID, to name: String) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tracks[index].name = trimmed.isEmpty ? nil : trimmed
    }

    func audioTrackWithRoom(for clip: Clip) -> Track? {
        let candidates = tracks(withRole: .audio)
        return candidates.first { $0.isFree(from: clip.startInSeconds, to: clip.endInSeconds) }
    }
}
