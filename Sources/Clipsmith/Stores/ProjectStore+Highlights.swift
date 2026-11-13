import Foundation

extension ProjectStore {
    @discardableResult
    func addHighlight(from start: TimeInterval, to end: TimeInterval) -> Highlight.ID? {
        guard end - start >= Highlight.minimumDurationInSeconds else { return nil }
        let name = String(format: localized("highlight.defaultName"), project.highlights.count + 1)
        let highlight = Highlight(name: name, startInSeconds: start, endInSeconds: end)
        var addedID: Highlight.ID?
        mutate { addedID = $0.addHighlight(highlight) }
        return addedID
    }

    @discardableResult
    func suggestHighlights(
        for clip: Clip, peaks: [Float],
        duration: TimeInterval = HighlightSuggester.defaultDurationInSeconds,
        count: Int = HighlightSuggester.defaultCount
    ) -> Int {
        let ranges = HighlightSuggester.suggestions(
            peaks: peaks, from: clip.sourceStartInSeconds, to: clip.sourceEndInSeconds,
            duration: duration, count: count)
        let fresh = newTimelineRanges(from: ranges, of: clip)
        guard !fresh.isEmpty else { return 0 }
        mutate { project in
            for range in fresh {
                let name = String(
                    format: localized("highlight.defaultName"), project.highlights.count + 1)
                project.addHighlight(
                    Highlight(name: name, startInSeconds: range.start, endInSeconds: range.end))
            }
        }
        return fresh.count
    }

    private func newTimelineRanges(
        from sourceRanges: [ClosedRange<TimeInterval>], of clip: Clip
    ) -> [(start: TimeInterval, end: TimeInterval)] {
        let existing = project.highlights
        return sourceRanges.map { range in
            (
                start: clip.timelineTime(forSourceTime: range.lowerBound),
                end: clip.timelineTime(forSourceTime: range.upperBound)
            )
        }.filter { candidate in
            !existing.contains {
                $0.startInSeconds < candidate.end && candidate.start < $0.endInSeconds
            }
        }
    }

    static let faceSampleCount = 8
    static let trackingSecondsPerSample: TimeInterval = 1.5
    static let minimumTrackingSamples = 4
    static let maximumTrackingSamples = 30

    @discardableResult
    func autoFrameHighlight(_ id: Highlight.ID, using locator: FaceLocating) async -> Bool {
        guard let highlight = project.highlight(withID: id),
            let clip = videoClip(at: (highlight.startInSeconds + highlight.endInSeconds) / 2),
            let url = clip.sourceURL
        else { return false }
        let count = Self.faceSampleCount
        let times = (0..<count).map { index -> TimeInterval in
            let fraction = (Double(index) + 0.5) / Double(count)
            let timeline = highlight.startInSeconds + fraction * highlight.durationInSeconds
            let source = clip.sourceStartInSeconds + (timeline - clip.startInSeconds) * clip.speed
            return min(max(source, clip.sourceStartInSeconds), clip.sourceEndInSeconds)
        }
        guard let sample = await locator.faceSample(in: url, at: times),
            let offset = FaceFraming.offsetX(
                faceCenters: sample.centers, sourceAspect: sample.sourceAspect,
                canvasAspect: Project.highlightCanvas.aspectRatio)
        else { return false }
        setHighlightFraming(id, offsetX: offset)
        return true
    }

    @discardableResult
    func trackFaceInHighlight(_ id: Highlight.ID, using locator: FaceLocating) async -> Bool {
        guard let highlight = project.highlight(withID: id),
            let clip = videoClip(at: (highlight.startInSeconds + highlight.endInSeconds) / 2),
            let url = clip.sourceURL
        else { return false }
        let times = trackingTimes(for: highlight, in: clip)
        guard let sample = await locator.faceSample(in: url, at: times),
            let frames = FaceFraming.keyframes(
                faceCenters: sample.centers,
                at: sample.times.map { relativeTime(ofSourceTime: $0, in: clip, for: highlight) },
                sourceAspect: sample.sourceAspect,
                canvasAspect: Project.highlightCanvas.aspectRatio)
        else { return false }
        mutate { $0.replaceFramingKeyframes(of: id, with: frames) }
        return true
    }

    private func trackingTimes(for highlight: Highlight, in clip: Clip) -> [TimeInterval] {
        let count = min(
            max(
                Int(highlight.durationInSeconds / Self.trackingSecondsPerSample),
                Self.minimumTrackingSamples),
            Self.maximumTrackingSamples)
        return (0..<count).map { index in
            let fraction = (Double(index) + 0.5) / Double(count)
            let timeline = highlight.startInSeconds + fraction * highlight.durationInSeconds
            let source = clip.sourceStartInSeconds + (timeline - clip.startInSeconds) * clip.speed
            return min(max(source, clip.sourceStartInSeconds), clip.sourceEndInSeconds)
        }
    }

    private func relativeTime(
        ofSourceTime source: TimeInterval, in clip: Clip, for highlight: Highlight
    ) -> TimeInterval {
        clip.timelineTime(forSourceTime: source) - highlight.startInSeconds
    }

    @discardableResult
    func addFramingKeyframeAtPlayhead(to id: Highlight.ID) -> FramingKeyframe.ID? {
        guard let highlight = project.highlight(withID: id) else { return nil }
        let time = playheadInSeconds - highlight.startInSeconds
        var added: FramingKeyframe.ID?
        mutate { added = $0.addFramingKeyframe(to: id, at: time) }
        return added
    }

    func setFramingKeyframeOffset(
        _ keyframeID: FramingKeyframe.ID, in id: Highlight.ID, to offsetX: Double
    ) {
        mutate(coalescingKey: "framing-key-\(keyframeID)") {
            $0.setFramingKeyframeOffset(keyframeID, in: id, to: offsetX)
        }
    }

    func setFramingKeyframeEasing(
        _ keyframeID: FramingKeyframe.ID, in id: Highlight.ID, to easing: Easing
    ) {
        mutate { $0.setFramingKeyframeEasing(keyframeID, in: id, to: easing) }
    }

    func removeFramingKeyframe(_ keyframeID: FramingKeyframe.ID, from id: Highlight.ID) {
        mutate { $0.removeFramingKeyframe(keyframeID, from: id) }
    }

    func clearFramingKeyframes(of id: Highlight.ID) {
        mutate { $0.clearFramingKeyframes(of: id) }
    }

    private func videoClip(at time: TimeInterval) -> Clip? {
        project.tracks
            .filter { $0.role == .main || $0.role == .broll }
            .flatMap(\.clips)
            .first { $0.mediaKind == .video && $0.startInSeconds <= time && time < $0.endInSeconds }
    }

    func renameHighlight(_ id: Highlight.ID, to name: String) {
        mutate(coalescingKey: "highlight-name-\(id)") { $0.renameHighlight(id, to: name) }
    }

    func removeHighlight(_ id: Highlight.ID) {
        mutate { $0.removeHighlight(id) }
    }

    func setHighlightRange(_ id: Highlight.ID, start: TimeInterval, end: TimeInterval) {
        mutate(coalescingKey: "highlight-range-\(id)") {
            $0.setHighlightRange(id, start: start, end: end)
        }
    }

    func setHighlightFitMode(_ id: Highlight.ID, to mode: FitMode) {
        mutate { $0.setHighlightFitMode(id, to: mode) }
    }

    func setHighlightFraming(_ id: Highlight.ID, offsetX: Double) {
        mutate(coalescingKey: "highlight-framing-\(id)") {
            $0.setHighlightFraming(id, offsetX: offsetX)
        }
    }
}
