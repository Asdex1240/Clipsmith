import Foundation

extension Project {
    func isLocked(_ clipID: Clip.ID) -> Bool {
        guard let position = location(of: clipID) else { return false }
        return tracks[position.track].isLocked
    }

    func unlocked(_ ids: Set<Clip.ID>) -> Set<Clip.ID> {
        ids.filter { !isLocked($0) }
    }

    func isTrackLocked(_ id: Track.ID) -> Bool {
        tracks.first { $0.id == id }?.isLocked ?? false
    }

    mutating func toggleMute(ofTrack id: Track.ID) {
        guard let index = tracks.firstIndex(where: { $0.id == id }),
            tracks[index].role.canBeMuted
        else { return }
        tracks[index].isMuted.toggle()
    }

    mutating func toggleVisibility(ofTrack id: Track.ID) {
        guard let index = tracks.firstIndex(where: { $0.id == id }),
            tracks[index].role.canBeHidden
        else { return }
        tracks[index].isHidden.toggle()
    }

    mutating func toggleLock(ofTrack id: Track.ID) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[index].isLocked.toggle()
    }

    var renderedForPlayback: Project {
        var result = self
        for index in result.tracks.indices {
            if result.tracks[index].isMuted { result.tracks[index].silenceClips() }
            if result.tracks[index].isHidden { result.tracks[index].hideClips() }
        }
        return result
    }
}

extension Track {
    fileprivate mutating func silenceClips() {
        for index in clips.indices { clips[index].volume = 0 }
    }

    fileprivate mutating func hideClips() {
        for index in clips.indices { clips[index] = clips[index].hiddenFromPicture() }
    }
}

extension Clip {
    fileprivate func hiddenFromPicture() -> Clip {
        var clip = self
        clip.opacity = 0
        for index in clip.keyframes.indices { clip.keyframes[index].state.opacity = 0 }
        if mediaKind == .text { clip.textLayer = nil }
        return clip
    }
}
