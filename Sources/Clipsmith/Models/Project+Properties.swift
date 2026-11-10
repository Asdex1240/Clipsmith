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

    /// `time` is the playhead: when the clip has keyframes, the change lands on the keyframe at that moment.
    mutating func setTransform(of id: Clip.ID, scale: Double, rotationInDegrees: Double, at time: TimeInterval? = nil) {
        updateClip(id) { clip in
            clip.updatingVisual(at: time) {
                $0.scale = scale
                $0.rotationInDegrees = rotationInDegrees
            }
        }
    }

    mutating func setTransition(of id: Clip.ID, to transition: ClipTransition?) {
        updateClip(id) { clip in
            var updated = clip
            updated.transition = transition
            return updated
        }
    }

    /// The visual clip that ends exactly where `id` starts on the same track, if any.
    func clipBeforeAndTouching(_ id: Clip.ID) -> Clip? {
        guard let position = location(of: id), [.main, .broll].contains(tracks[position.track].role) else { return nil }
        let track = tracks[position.track]
        let clip = track.clips[position.clip]
        return track.clips
            .filter { $0.id != id && abs($0.endInSeconds - clip.startInSeconds) <= Self.transitionAdjacencyToleranceInSeconds }
            .first
    }

    static let transitionAdjacencyToleranceInSeconds: TimeInterval = 0.001

    mutating func setColor(of id: Clip.ID, to adjustments: ColorAdjustments) {
        updateClip(id) { clip in
            var updated = clip
            updated.color = adjustments.clamped()
            return updated
        }
    }

    mutating func setCrop(of id: Clip.ID, to insets: CropInsets) {
        updateClip(id) { clip in
            var updated = clip
            updated.crop = insets.clamped()
            return updated
        }
    }

    mutating func setOpacity(of id: Clip.ID, to value: Double, at time: TimeInterval? = nil) {
        updateClip(id) { clip in clip.updatingVisual(at: time) { $0.opacity = value } }
    }

    mutating func addKeyframe(to id: Clip.ID, atTimelineTime time: TimeInterval) {
        updateClip(id) { $0.addingKeyframe(atClipTime: time - $0.startInSeconds) }
    }

    mutating func removeKeyframe(_ keyframeID: Keyframe.ID, from id: Clip.ID) {
        updateClip(id) { $0.removingKeyframe(keyframeID) }
    }

    mutating func clearKeyframes(of id: Clip.ID) {
        updateClip(id) { $0.clearingKeyframes() }
    }

    mutating func setSpeed(of id: Clip.ID, to value: Double) {
        guard let position = location(of: id) else { return }
        let track = tracks[position.track]
        let clip = track.clips[position.clip]
        tracks[position.track].clips[position.clip] = clip.settingSpeed(value, notEndingAfter: track.nextStart(after: clip))
    }

    mutating func setOffset(of id: Clip.ID, x: Double, y: Double, at time: TimeInterval? = nil) {
        updateClip(id) { clip in
            clip.updatingVisual(at: time) {
                $0.offsetX = x
                $0.offsetY = y
            }
        }
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
        audio.opacity = 1
        audio.color = ColorAdjustments()
        audio.crop = CropInsets()
        audio.keyframes = []
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

    /// Adds a text clip for each line; returns how many fit on the text track.
    @discardableResult
    mutating func addSubtitles(_ lines: [SubtitleLine]) -> Int {
        lines.reduce(0) { added, line in
            addTextClip(.subtitle(line.text), at: line.startInSeconds, duration: line.durationInSeconds) == nil ? added : added + 1
        }
    }

    private mutating func updateClip(_ id: Clip.ID, _ transform: (Clip) -> Clip) {
        guard let position = location(of: id) else { return }
        tracks[position.track].clips[position.clip] = transform(tracks[position.track].clips[position.clip])
    }
}
