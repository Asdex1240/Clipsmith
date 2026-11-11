import Foundation

extension ProjectStore {
    func setCanvas(_ format: CanvasFormat) {
        mutate { $0.canvas = format }
    }

    func setAutoFitCanvas(_ enabled: Bool) {
        mutate { $0.autoFitCanvas = enabled }
    }

    func setFitMode(of id: Clip.ID, to mode: FitMode) {
        mutate { $0.setFitMode(of: id, to: mode) }
    }

    func setTransform(of id: Clip.ID, scale: Double, rotationInDegrees: Double) {
        let time = playheadInSeconds
        mutate(coalescingKey: "transform-\(id)") {
            $0.setTransform(of: id, scale: scale, rotationInDegrees: rotationInDegrees, at: time)
        }
    }

    func setTransition(of id: Clip.ID, to transition: ClipTransition?) {
        mutate { $0.setTransition(of: id, to: transition) }
    }

    func setColor(of id: Clip.ID, to adjustments: ColorAdjustments) {
        mutate(coalescingKey: "color-\(id)") { $0.setColor(of: id, to: adjustments) }
    }

    func setCrop(of id: Clip.ID, to insets: CropInsets) {
        mutate(coalescingKey: "crop-\(id)") { $0.setCrop(of: id, to: insets) }
    }

    func setOpacity(of id: Clip.ID, to value: Double) {
        let time = playheadInSeconds
        mutate(coalescingKey: "opacity-\(id)") { $0.setOpacity(of: id, to: value, at: time) }
    }

    func addKeyframeAtPlayhead(to id: Clip.ID) {
        let time = playheadInSeconds
        mutate { $0.addKeyframe(to: id, atTimelineTime: time) }
    }

    func removeKeyframe(_ keyframeID: Keyframe.ID, from id: Clip.ID) {
        mutate { $0.removeKeyframe(keyframeID, from: id) }
    }

    func setKeyframeEasing(_ easing: Easing, for keyframeID: Keyframe.ID, in id: Clip.ID) {
        mutate { $0.setKeyframeEasing(easing, for: keyframeID, in: id) }
    }

    func clearKeyframes(of id: Clip.ID) {
        mutate { $0.clearKeyframes(of: id) }
    }

    func resetTransform(of id: Clip.ID) {
        mutate {
            $0.clearKeyframes(of: id)
            $0.setOffset(of: id, x: 0, y: 0)
            $0.setTransform(of: id, scale: 1, rotationInDegrees: 0)
        }
    }

    func setOffset(of id: Clip.ID, x: Double, y: Double) {
        let time = playheadInSeconds
        mutate(coalescingKey: "offset-\(id)") { $0.setOffset(of: id, x: x, y: y, at: time) }
    }

    func detachAudio(ofClip id: Clip.ID) {
        var addedID: Clip.ID?
        mutate { addedID = $0.detachAudio(ofClip: id) }
        if let addedID { selectClip(addedID) }
    }

    func replaceMedia(from original: URL, to replacement: URL) {
        mutate { $0.remapSources([original: replacement]) }
    }

    func addTextAtPlayhead() {
        let layer = TextLayer(content: localized("text.default"))
        var addedID: Clip.ID?
        mutate {
            addedID = $0.addTextClip(
                layer, at: playheadInSeconds, duration: Self.defaultTextDurationInSeconds)
        }
        if let addedID { selectClip(addedID) }
    }

    @discardableResult
    func addSubtitles(
        _ lines: [SubtitleLine], style: TextStylePreset = .classic,
        animation: TextAnimation = TextAnimation(), highlightColor: RGBAColor? = nil
    ) -> Int {
        var added = 0
        mutate {
            added = $0.addSubtitles(
                lines, style: style, animation: animation, highlightColor: highlightColor)
        }
        return added
    }

    func updateTextLayer(of id: Clip.ID, field: String = "", _ change: (inout TextLayer) -> Void) {
        mutate(coalescingKey: "text-\(id)-\(field)") { $0.updateTextLayer(of: id, change) }
    }

    func setSpeed(of id: Clip.ID, to value: Double) {
        mutate(coalescingKey: "speed-\(id)") { $0.setSpeed(of: id, to: value) }
    }

    func setVolume(of id: Clip.ID, to value: Double) {
        mutate(coalescingKey: "volume-\(id)") { $0.setVolume(of: id, to: value) }
    }

    func setFadeIn(of id: Clip.ID, to seconds: TimeInterval) {
        mutate(coalescingKey: "fadeIn-\(id)") { $0.setFadeIn(of: id, to: seconds) }
    }

    func setFadeOut(of id: Clip.ID, to seconds: TimeInterval) {
        mutate(coalescingKey: "fadeOut-\(id)") { $0.setFadeOut(of: id, to: seconds) }
    }
}
