import Foundation
import Observation

@MainActor
@Observable
final class ProjectStore {
    static let defaultPointsPerSecond = 40.0
    static let minimumPointsPerSecond = 4.0
    static let maximumPointsPerSecond = 400.0
    static let zoomFactor = 1.25
    static let snapThresholdInPoints = 8.0
    static let defaultTextDurationInSeconds: TimeInterval = 3
    static let maximumUndoSteps = 100
    static let frameDurationInSeconds: TimeInterval = 1.0 / 30
    static let jumpDurationInSeconds: TimeInterval = 1
    private static let editPointToleranceInSeconds: TimeInterval = 1e-6
    static let coalescingWindowInSeconds: TimeInterval = 1

    private(set) var project: Project {
        didSet { projectRevision += 1 }
    }
    private(set) var projectRevision = 0
    private(set) var selectedClipID: Clip.ID?
    private(set) var selectedClipIDs: Set<Clip.ID> = []
    private(set) var playheadInSeconds: TimeInterval = 0
    private(set) var isSnappingEnabled = true
    private(set) var pointsPerSecond = ProjectStore.defaultPointsPerSecond
    private var undoStack: [Project] = []
    private var redoStack: [Project] = []
    @ObservationIgnored private var lastMutationKey: String?
    @ObservationIgnored private var lastMutationDate = Date.distantPast
    @ObservationIgnored private var clipboard: [ClipboardEntry] = []
    @ObservationIgnored private let now: () -> Date

    init(project: Project, now: @escaping () -> Date = Date.init) {
        self.project = project
        self.now = now
    }

    var selectedClip: Clip? {
        selectedClipID.flatMap { project.clip(withID: $0) }
    }

    var hasMultipleSelected: Bool { selectedClipIDs.count > 1 }

    var selectedClips: [Clip] {
        project.tracks.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }.sorted { $0.startInSeconds < $1.startInSeconds }
    }

    var selectionIsGrouped: Bool {
        selectedClips.contains { $0.groupID != nil }
    }

    var canGroupSelection: Bool {
        selectedClipIDs.count >= 2
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    func load(_ newProject: Project) {
        project = newProject
        undoStack = []
        redoStack = []
        lastMutationKey = nil
        setSelection([], primary: nil)
        playheadInSeconds = 0
    }

    func setProjectName(_ name: String) {
        project.name = name
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project)
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project)
        restore(next)
    }

    func selectClip(_ id: Clip.ID?) {
        guard let id else {
            setSelection([], primary: nil)
            return
        }
        setSelection(project.groupMembers(of: id), primary: id)
    }

    func toggleSelection(of id: Clip.ID) {
        let members = project.groupMembers(of: id)
        guard !members.isEmpty else { return }
        if selectedClipIDs.contains(id) {
            let remaining = selectedClipIDs.subtracting(members)
            setSelection(remaining, primary: selectedClipID)
        } else {
            setSelection(selectedClipIDs.union(members), primary: id)
        }
    }

    func selectAll() {
        let all = project.allClipIDs
        let candidates = [selectedClipID, selectedClips.first?.id].compactMap { $0 }
        setSelection(all, primary: candidates.first { all.contains($0) })
    }

    private func setSelection(_ ids: Set<Clip.ID>, primary: Clip.ID?) {
        selectedClipIDs = ids
        if let primary, ids.contains(primary) {
            selectedClipID = primary
        } else {
            selectedClipID = ids.first
        }
    }

    func setPlayhead(near proposed: TimeInterval) {
        let candidates = project.snapPoints(excluding: nil, playhead: -1)
        let snapped = Snapping.snap(max(0, proposed), to: candidates, within: snapThresholdInSeconds)
        playheadInSeconds = max(0, snapped)
    }

    func followPlayback(at time: TimeInterval) {
        playheadInSeconds = max(0, time)
    }

    func movePlayhead(to time: TimeInterval) {
        playheadInSeconds = min(max(0, time), project.durationInSeconds)
    }

    func stepPlayhead(byFrames frames: Int) {
        movePlayhead(to: playheadInSeconds + Double(frames) * Self.frameDurationInSeconds)
    }

    func jumpPlayhead(bySeconds seconds: TimeInterval) {
        movePlayhead(to: playheadInSeconds + seconds)
    }

    func goToStart() {
        movePlayhead(to: 0)
    }

    func goToEnd() {
        movePlayhead(to: project.durationInSeconds)
    }

    func goToPreviousEdit() {
        let tolerance = Self.editPointToleranceInSeconds
        movePlayhead(to: editPoints.last { $0 < playheadInSeconds - tolerance } ?? 0)
    }

    func goToNextEdit() {
        let tolerance = Self.editPointToleranceInSeconds
        movePlayhead(to: editPoints.first { $0 > playheadInSeconds + tolerance } ?? project.durationInSeconds)
    }

    func toggleSnapping() {
        isSnappingEnabled.toggle()
    }

    func zoomIn() {
        setZoom(pointsPerSecond * Self.zoomFactor)
    }

    func zoomOut() {
        setZoom(pointsPerSecond / Self.zoomFactor)
    }

    func zoom(byScrollDelta delta: Double) {
        setZoom(pointsPerSecond * exp(delta * 0.02))
    }

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
        mutate { addedID = $0.addTextClip(layer, at: playheadInSeconds, duration: Self.defaultTextDurationInSeconds) }
        if let addedID { selectClip(addedID) }
    }

    @discardableResult
    func addSubtitles(_ lines: [SubtitleLine], style: TextStylePreset = .classic, animation: TextAnimation = TextAnimation()) -> Int {
        var added = 0
        mutate { added = $0.addSubtitles(lines, style: style, animation: animation) }
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

    func dropStart(duration: TimeInterval, on track: Track, near proposed: TimeInterval) -> TimeInterval {
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
        let start = Snapping.snapStart(max(0, proposedStart), duration: clip.durationInSeconds, to: candidates, within: snapThresholdInSeconds)
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

    func addTrack(role: Track.Role) {
        mutate { $0.addTrack(role: role) }
    }

    func removeTrack(_ id: Track.ID) {
        mutate { $0.removeTrack(id) }
        let existing = selectedClipIDs.intersection(project.allClipIDs)
        if existing != selectedClipIDs { setSelection(existing, primary: selectedClipID) }
    }

    func moveTrack(_ id: Track.ID, direction: TrackMoveDirection) {
        mutate { $0.moveTrack(id, direction: direction) }
    }

    func renameTrack(_ id: Track.ID, to name: String) {
        mutate(coalescingKey: "track-name-\(id)") { $0.renameTrack(id, to: name) }
    }

    func trimToPlayhead(edge: ClipEdge) {
        let time = playheadInSeconds
        let targets = splitTargetIDs()
        mutate { project in targets.forEach { project.trimClip($0, edge: edge, to: time) } }
    }

    func copySelectedClip() {
        let entries = project.clipboardEntries(for: selectedClips)
        guard !entries.isEmpty else { return }
        clipboard = entries
    }

    func cutSelectedClip() {
        copySelectedClip()
        deleteSelectedClip()
    }

    func pasteAtPlayhead() {
        guard let first = clipboard.map(\.clip.startInSeconds).min() else { return }
        place(clipboard, shiftedBy: playheadInSeconds - first)
    }

    func duplicateSelectedClip() {
        let entries = project.clipboardEntries(for: selectedClips)
        guard let first = entries.map(\.clip.startInSeconds).min(),
              let last = entries.map(\.clip.endInSeconds).max() else { return }
        place(entries, shiftedBy: last - first)
    }

    private func place(_ entries: [ClipboardEntry], shiftedBy offset: TimeInterval) {
        var added: [Clip.ID] = []
        mutate { added = $0.insertCopies(of: entries, shiftedBy: offset) }
        guard let last = added.last else { return }
        setSelection(Set(added), primary: last)
    }

    private func canvasFittingFirstClip(_ item: MediaItem) -> CanvasFormat? {
        guard project.autoFitCanvas, !project.hasVisualClips,
              item.kind == .video || item.kind == .image,
              let size = item.pixelSize else { return nil }
        return CanvasFormat.fitting(size)
    }

    private var editPoints: [TimeInterval] {
        Array(Set(project.snapPoints(excluding: nil, playhead: 0))).sorted()
    }

    private var snapThresholdInSeconds: TimeInterval {
        guard isSnappingEnabled else { return 0 }
        return Self.snapThresholdInPoints / pointsPerSecond
    }

    private func mutate(coalescingKey: String? = nil, _ change: (inout Project) -> Void) {
        var updated = project
        change(&updated)
        guard updated != project else { return }
        recordUndoStep(coalescingKey: coalescingKey)
        project = updated
    }

    private func recordUndoStep(coalescingKey: String?) {
        let timestamp = now()
        defer {
            lastMutationKey = coalescingKey
            lastMutationDate = timestamp
        }
        if let coalescingKey, coalescingKey == lastMutationKey,
           timestamp.timeIntervalSince(lastMutationDate) <= Self.coalescingWindowInSeconds {
            return
        }
        undoStack.append(project)
        if undoStack.count > Self.maximumUndoSteps { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func restore(_ snapshot: Project) {
        var restored = snapshot
        restored.name = project.name
        project = restored
        lastMutationKey = nil
        let existing = selectedClipIDs.intersection(project.allClipIDs)
        if existing != selectedClipIDs { setSelection(existing, primary: selectedClipID) }
    }

    private func setZoom(_ proposed: Double) {
        pointsPerSecond = min(max(proposed, Self.minimumPointsPerSecond), Self.maximumPointsPerSecond)
    }

    private func snappedStart(_ proposed: TimeInterval, duration: TimeInterval, excluding id: Clip.ID?) -> TimeInterval {
        let candidates = project.snapPoints(excluding: id, playhead: playheadInSeconds)
        return Snapping.snapStart(max(0, proposed), duration: duration, to: candidates, within: snapThresholdInSeconds)
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
