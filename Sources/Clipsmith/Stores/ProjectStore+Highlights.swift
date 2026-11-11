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
        for clip: Clip, peaks: [Float], duration: TimeInterval = HighlightSuggester.defaultDurationInSeconds,
        count: Int = HighlightSuggester.defaultCount
    ) -> Int {
        let ranges = HighlightSuggester.suggestions(
            peaks: peaks, from: clip.sourceStartInSeconds, to: clip.sourceEndInSeconds,
            duration: duration, count: count)
        let existing = project.highlights
        let fresh = ranges.map { range in
            (
                start: clip.startInSeconds + (range.lowerBound - clip.sourceStartInSeconds) / clip.speed,
                end: clip.startInSeconds + (range.upperBound - clip.sourceStartInSeconds) / clip.speed
            )
        }.filter { candidate in
            !existing.contains { $0.startInSeconds < candidate.end && candidate.start < $0.endInSeconds }
        }
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

    func setHighlightFraming(_ id: Highlight.ID, offsetX: Double) {
        mutate(coalescingKey: "highlight-framing-\(id)") {
            $0.setHighlightFraming(id, offsetX: offsetX)
        }
    }
}
