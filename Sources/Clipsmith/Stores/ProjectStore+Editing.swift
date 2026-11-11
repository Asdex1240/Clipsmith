import Foundation

extension ProjectStore {
    func appendToTimeline(_ item: MediaItem) {
        let role = Track.Role.preferred(for: item.kind)
        guard let track = project.track(withRole: role) else { return }
        addMedia(item, toTrack: track.id, at: track.endInSeconds)
    }

    func addMedia(_ item: MediaItem, toTrack trackID: Track.ID, at proposedStart: TimeInterval) {
        let start = snappedStart(proposedStart, duration: item.durationInSeconds, excluding: nil)
        let clip = Clip(item: item, startInSeconds: start)
        let fittedCanvas = canvasFittingFirstClip(item)
        var added = false
        mutate {
            added = $0.addClip(clip, toTrack: trackID)
            if added, let fittedCanvas { $0.canvas = fittedCanvas }
        }
        if added { selectClip(clip.id) }
    }

    func dropStart(
        duration: TimeInterval, on track: Track, near proposed: TimeInterval
    ) -> TimeInterval {
        let snapped = snappedStart(proposed, duration: duration, excluding: nil)
        return track.nearestFreeStart(forDuration: duration, near: snapped, excluding: nil)
    }

    func moveClip(_ id: Clip.ID, toTrack trackID: Track.ID, near proposedStart: TimeInterval) {
        guard let clip = project.clip(withID: id) else { return }
        let start = snappedStart(proposedStart, duration: clip.durationInSeconds, excluding: id)
        mutate { $0.moveClip(id, toTrack: trackID, startingAt: start) }
    }

    func trimClip(_ id: Clip.ID, edge: ClipEdge, near proposedTime: TimeInterval) {
        let candidates = project.snapPoints(excluding: id, playhead: playheadInSeconds)
        let time = Snapping.snap(proposedTime, to: candidates, within: snapThresholdInSeconds)
        mutate(coalescingKey: "trim-\(id)-\(edge)") { $0.trimClip(id, edge: edge, to: time) }
    }

    func splitAtPlayhead() {
        let targets = splitTargetIDs()
        let time = playheadInSeconds
        mutate { $0.splitClips(targets, at: time) }
    }

    @discardableResult
    func removeSilences(_ ranges: [Range<TimeInterval>], from clipID: Clip.ID) -> Int {
        guard !ranges.isEmpty else { return 0 }
        var removed = 0
        mutate { removed = $0.removeRanges(ranges, from: clipID) }
        return removed
    }

    func deleteSelectedClip() {
        let ids = selectedClipIDs
        guard !ids.isEmpty else { return }
        mutate { $0.deleteClips(ids) }
        selectClip(nil)
    }

    func rippleDeleteSelectedClip() {
        let ids = selectedClipIDs
        guard !ids.isEmpty else { return }
        mutate { $0.rippleDeleteClips(ids) }
        selectClip(nil)
    }

    func moveSelection(draggedClip id: Clip.ID, near proposedStart: TimeInterval) {
        let ids = selectedClipIDs
        guard let clip = project.clip(withID: id), ids.contains(id) else { return }
        let candidates = project.snapPoints(excluding: ids, playhead: playheadInSeconds)
        let start = Snapping.snapStart(
            max(0, proposedStart), duration: clip.durationInSeconds, to: candidates,
            within: snapThresholdInSeconds)
        let delta = start - clip.startInSeconds
        mutate { $0.moveClips(ids, by: delta) }
    }

    func groupSelection() {
        let ids = selectedClipIDs
        mutate { $0.group(ids) }
    }

    func ungroupSelection() {
        let ids = selectedClipIDs
        mutate { $0.ungroup(ids) }
    }

    func toggleGroupSelection() {
        if selectionIsGrouped {
            ungroupSelection()
        } else {
            groupSelection()
        }
    }

    func trimToPlayhead(edge: ClipEdge) {
        let time = playheadInSeconds
        let targets = splitTargetIDs()
        mutate { project in targets.forEach { project.trimClip($0, edge: edge, to: time) } }
    }

    func toggleMarkerAtPlayhead() {
        let time = playheadInSeconds
        mutate { $0.toggleMarker(at: time) }
    }

    func renameMarker(_ id: Marker.ID, to name: String) {
        mutate(coalescingKey: "marker-\(id)") { $0.renameMarker(id, to: name) }
    }

    func removeMarker(_ id: Marker.ID) {
        mutate { $0.removeMarker(id) }
    }

    private func canvasFittingFirstClip(_ item: MediaItem) -> CanvasFormat? {
        guard project.autoFitCanvas, !project.hasVisualClips,
            item.kind == .video || item.kind == .image,
            let size = item.pixelSize
        else { return nil }
        return CanvasFormat.fitting(size)
    }

    private func snappedStart(
        _ proposed: TimeInterval, duration: TimeInterval, excluding id: Clip.ID?
    ) -> TimeInterval {
        let candidates = project.snapPoints(excluding: id, playhead: playheadInSeconds)
        return Snapping.snapStart(
            max(0, proposed), duration: duration, to: candidates, within: snapThresholdInSeconds)
    }

    private func splitTargetIDs() -> [Clip.ID] {
        if !selectedClipIDs.isEmpty {
            return selectedClips.map(\.id)
        }
        return project.tracks.flatMap(\.clips)
            .filter { $0.startInSeconds < playheadInSeconds && playheadInSeconds < $0.endInSeconds }
            .map(\.id)
    }
}
