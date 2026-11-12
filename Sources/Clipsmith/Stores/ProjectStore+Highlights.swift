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
