import Foundation

extension Project {
    static let highlightCanvas = CanvasFormat.portrait
    static let framingKeyframeSpacingInSeconds: TimeInterval = 0.05

    func highlight(withID id: Highlight.ID) -> Highlight? {
        highlights.first { $0.id == id }
    }

    @discardableResult
    mutating func addHighlight(_ highlight: Highlight) -> Highlight.ID {
        highlights.append(highlight)
        highlights.sort { $0.startInSeconds < $1.startInSeconds }
        return highlight.id
    }

    mutating func renameHighlight(_ id: Highlight.ID, to name: String) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func removeHighlight(_ id: Highlight.ID) {
        highlights.removeAll { $0.id == id }
    }

    mutating func setHighlightRange(
        _ id: Highlight.ID, start: TimeInterval, end: TimeInterval
    ) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index] = highlights[index].withRangeKeepingKeyframePositions(
            start: start, end: end)
        highlights.sort { $0.startInSeconds < $1.startInSeconds }
    }

    mutating func setHighlightFraming(_ id: Highlight.ID, offsetX: Double) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].framingOffsetX = Highlight.clampedFraming(offsetX)
    }

    @discardableResult
    mutating func addFramingKeyframe(
        to id: Highlight.ID, at time: TimeInterval, offsetX: Double? = nil
    ) -> FramingKeyframe.ID? {
        guard let index = highlights.firstIndex(where: { $0.id == id }),
            time >= 0, time <= highlights[index].durationInSeconds
        else { return nil }
        let curve = highlights[index].framingCurve
        let value = offsetX ?? curve.offsetX(at: time)
        if !curve.isAnimated, time > Self.framingKeyframeSpacingInSeconds {
            highlights[index].framingKeyframes.append(
                FramingKeyframe(timeInSeconds: 0, offsetX: curve.staticOffsetX))
        }
        if let existing = highlights[index].framingKeyframes.firstIndex(where: {
            abs($0.timeInSeconds - time) < Self.framingKeyframeSpacingInSeconds
        }) {
            highlights[index].framingKeyframes[existing].offsetX = Highlight.clampedFraming(value)
            return highlights[index].framingKeyframes[existing].id
        }
        let frame = FramingKeyframe(timeInSeconds: time, offsetX: value)
        highlights[index].framingKeyframes.append(frame)
        highlights[index].framingKeyframes.sort { $0.timeInSeconds < $1.timeInSeconds }
        return frame.id
    }

    mutating func removeFramingKeyframe(_ keyframeID: FramingKeyframe.ID, from id: Highlight.ID) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].framingKeyframes.removeAll { $0.id == keyframeID }
    }

    mutating func setFramingKeyframeOffset(
        _ keyframeID: FramingKeyframe.ID, in id: Highlight.ID, to offsetX: Double
    ) {
        updateFramingKeyframe(keyframeID, in: id) { $0.offsetX = Highlight.clampedFraming(offsetX) }
    }

    mutating func setFramingKeyframeEasing(
        _ keyframeID: FramingKeyframe.ID, in id: Highlight.ID, to easing: Easing
    ) {
        updateFramingKeyframe(keyframeID, in: id) { $0.easing = easing }
    }

    mutating func replaceFramingKeyframes(of id: Highlight.ID, with keyframes: [FramingKeyframe]) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].framingKeyframes = keyframes.filter {
            $0.timeInSeconds <= highlights[index].durationInSeconds
        }.sorted { $0.timeInSeconds < $1.timeInSeconds }
    }

    mutating func clearFramingKeyframes(of id: Highlight.ID) {
        replaceFramingKeyframes(of: id, with: [])
    }

    private mutating func updateFramingKeyframe(
        _ keyframeID: FramingKeyframe.ID, in id: Highlight.ID,
        _ change: (inout FramingKeyframe) -> Void
    ) {
        guard let index = highlights.firstIndex(where: { $0.id == id }),
            let frame = highlights[index].framingKeyframes.firstIndex(where: {
                $0.id == keyframeID
            })
        else { return }
        change(&highlights[index].framingKeyframes[frame])
    }

    mutating func setHighlightFitMode(_ id: Highlight.ID, to mode: FitMode) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].fitMode = mode
    }

    func extracting(_ highlight: Highlight) -> Project {
        var result = self
        result.name = highlight.name
        result.canvas = Self.highlightCanvas
        result.autoFitCanvas = false
        result.highlights = []
        result.markers = markers.compactMap { shifted($0, within: highlight) }
        for index in result.tracks.indices {
            result.tracks[index].clips = tracks[index].clips.compactMap {
                extractedClip($0, from: highlight)
            }
        }
        result.clearOrphanTransitions()
        return result
    }

    private func extractedClip(_ clip: Clip, from highlight: Highlight) -> Clip? {
        guard
            var piece = clip.clipped(from: highlight.startInSeconds, to: highlight.endInSeconds)
        else { return nil }
        piece.startInSeconds = max(0, piece.startInSeconds - highlight.startInSeconds)
        guard piece.mediaKind == .video || piece.mediaKind == .image else { return piece }
        return piece.reframedForVertical(
            curve: highlight.framingCurve, fitMode: highlight.fitMode,
            pieceStartInHighlight: piece.startInSeconds)
    }

    private func shifted(_ marker: Marker, within highlight: Highlight) -> Marker? {
        guard marker.timeInSeconds >= highlight.startInSeconds,
            marker.timeInSeconds <= highlight.endInSeconds
        else { return nil }
        var moved = marker
        moved.timeInSeconds -= highlight.startInSeconds
        return moved
    }

    private mutating func clearOrphanTransitions() {
        let orphans = tracks.flatMap(\.clips)
            .filter { $0.transition != nil && clipBeforeAndTouching($0.id) == nil }
            .map(\.id)
        for id in orphans { setTransition(of: id, to: nil) }
    }
}

extension Clip {
    fileprivate func reframedForVertical(
        curve: FramingCurve, fitMode mode: FitMode, pieceStartInHighlight start: TimeInterval
    ) -> Clip {
        var clip = self
        clip.fitMode = mode
        clip.offsetY = 0
        guard mode == .fill else {
            clip.offsetX = 0
            clip.keyframes = keyframes.map { frame in
                var copy = frame
                copy.state.offsetX = 0
                copy.state.offsetY = 0
                return copy
            }
            return clip
        }
        guard curve.isAnimated else {
            clip.offsetX = curve.staticOffsetX
            for index in clip.keyframes.indices {
                clip.keyframes[index].state.offsetX = curve.staticOffsetX
                clip.keyframes[index].state.offsetY = 0
            }
            return clip
        }
        clip.offsetX = curve.offsetX(at: start)
        clip.keyframes = animatedFrames(following: curve, pieceStartInHighlight: start)
        return clip
    }

    private func animatedFrames(
        following curve: FramingCurve, pieceStartInHighlight start: TimeInterval
    ) -> [Keyframe] {
        var times: Set<TimeInterval> = [0, durationInSeconds]
        for (index, frame) in keyframes.enumerated() {
            if frame.timeInSeconds > 0 && frame.timeInSeconds < durationInSeconds {
                times.insert(frame.timeInSeconds)
            }
            guard index + 1 < keyframes.count, !frame.easing.isLinear else { continue }
            let span = keyframes[index + 1].timeInSeconds - frame.timeInSeconds
            for step in 1..<FramingCurve.subdivisionsPerEasedSegment {
                let time =
                    frame.timeInSeconds + span * Double(step)
                    / Double(FramingCurve.subdivisionsPerEasedSegment)
                if time > 0 && time < durationInSeconds { times.insert(time) }
            }
        }
        let window = start...(start + durationInSeconds)
        for time in curve.sampleTimes(from: window.lowerBound, to: window.upperBound) {
            times.insert(time - start)
        }
        return times.sorted().map { clipTime in
            var state = visualState(atClipTime: clipTime)
            state.offsetX = curve.offsetX(at: start + clipTime)
            state.offsetY = 0
            return Keyframe(timeInSeconds: clipTime, state: state)
        }
    }
}
