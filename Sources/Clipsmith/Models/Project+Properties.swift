import Foundation

extension Project {
    func trackRole(ofClip id: Clip.ID) -> Track.Role? {
        tracks.first { track in track.clips.contains { $0.id == id } }?.role
    }

    mutating func setVolume(of id: Clip.ID, to value: Double) {
        updateClip(id) { $0.settingVolume(value) }
    }

    mutating func setFadeIn(of id: Clip.ID, to seconds: TimeInterval) {
        updateClip(id) { $0.settingFadeIn(seconds) }
    }

    mutating func setFadeOut(of id: Clip.ID, to seconds: TimeInterval) {
        updateClip(id) { $0.settingFadeOut(seconds) }
    }

    mutating func setFitMode(of id: Clip.ID, to mode: FitMode) {
        updateClip(id) { $0.settingFitMode(mode) }
    }

    mutating func setTransform(of id: Clip.ID, scale: Double, rotationInDegrees: Double) {
        updateClip(id) { $0.settingTransform(scale: scale, rotationInDegrees: rotationInDegrees) }
    }

    mutating func setOffset(of id: Clip.ID, x: Double, y: Double) {
        updateClip(id) { $0.settingOffset(x: x, y: y) }
    }

    /// A video on the main track whose sound can still be moved to the audio track without overlapping other audio.
    func canDetachAudio(ofClip id: Clip.ID) -> Bool {
        guard let position = location(of: id), tracks[position.track].role == .main,
              let audio = track(withRole: .audio) else { return false }
        let clip = tracks[position.track].clips[position.clip]
        guard clip.mediaKind == .video, !clip.isAudioDetached else { return false }
        return !audio.clips.contains { other in
            clip.startInSeconds < other.endInSeconds - Track.overlapToleranceInSeconds
                && clip.endInSeconds > other.startInSeconds + Track.overlapToleranceInSeconds
        }
    }

    /// Copies the sound of a video clip to the audio track, at the same time and range, and silences the video.
    @discardableResult
    mutating func detachAudio(ofClip id: Clip.ID) -> Clip.ID? {
        guard canDetachAudio(ofClip: id), let position = location(of: id),
              let audioIndex = tracks.firstIndex(where: { $0.role == .audio }) else { return nil }
        var audio = tracks[position.track].clips[position.clip]
        audio.id = UUID()
        audio.mediaKind = .audio
        audio.fitMode = .fit
        audio.offsetX = 0
        audio.offsetY = 0
        tracks[position.track].clips[position.clip].isAudioDetached = true
        tracks[audioIndex].clips.append(audio)
        tracks[audioIndex].clips.sort { $0.startInSeconds < $1.startInSeconds }
        return audio.id
    }

    var hasVisualClips: Bool {
        tracks.contains { $0.clips.contains { $0.mediaKind == .video || $0.mediaKind == .image } }
    }

    mutating func updateTextLayer(of id: Clip.ID, _ change: (inout TextLayer) -> Void) {
        updateClip(id) { clip in
            guard var layer = clip.textLayer else { return clip }
            change(&layer)
            var updated = clip
            updated.textLayer = layer
            return updated
        }
    }

    @discardableResult
    mutating func addTextClip(_ layer: TextLayer, at start: TimeInterval, duration: TimeInterval) -> Clip.ID? {
        guard let track = track(withRole: .text) else { return nil }
        let clip = Clip(text: layer, startInSeconds: start, durationInSeconds: duration)
        return addClip(clip, toTrack: track.id) ? clip.id : nil
    }

    private mutating func updateClip(_ id: Clip.ID, _ transform: (Clip) -> Clip) {
        guard let position = location(of: id) else { return }
        tracks[position.track].clips[position.clip] = transform(tracks[position.track].clips[position.clip])
    }
}
