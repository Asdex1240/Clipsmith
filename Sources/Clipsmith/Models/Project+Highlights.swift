import Foundation

extension Project {
    static let highlightCanvas = CanvasFormat.portrait

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
        let current = highlights[index]
        highlights[index] = Highlight(
            id: id, name: current.name, startInSeconds: start, endInSeconds: end,
            framingOffsetX: current.framingOffsetX, fitMode: current.fitMode)
        highlights.sort { $0.startInSeconds < $1.startInSeconds }
    }

    mutating func setHighlightFraming(_ id: Highlight.ID, offsetX: Double) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].framingOffsetX = Highlight.clampedFraming(offsetX)
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
            offsetX: highlight.framingOffsetX, fitMode: highlight.fitMode)
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
    fileprivate func reframedForVertical(offsetX requested: Double, fitMode mode: FitMode) -> Clip {
        var framing = 0.0
        if mode == .fill { framing = requested }
        var clip = self
        clip.fitMode = mode
        clip.offsetX = framing
        clip.offsetY = 0
        for index in clip.keyframes.indices {
            clip.keyframes[index].state.offsetX = framing
            clip.keyframes[index].state.offsetY = 0
        }
        return clip
    }
}
