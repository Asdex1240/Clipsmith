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

    mutating func setOffset(of id: Clip.ID, x: Double, y: Double) {
        updateClip(id) { $0.settingOffset(x: x, y: y) }
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
