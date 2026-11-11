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
