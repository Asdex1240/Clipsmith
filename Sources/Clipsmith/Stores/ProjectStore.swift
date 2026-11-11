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
    private(set) var highlightMarks = HighlightMarks()
    private(set) var isSnappingEnabled = true
    private(set) var pointsPerSecond = ProjectStore.defaultPointsPerSecond
    private var undoStack: [Project] = []
    private var redoStack: [Project] = []
    @ObservationIgnored private var lastMutationKey: String?
    @ObservationIgnored private var lastMutationDate = Date.distantPast
    @ObservationIgnored var clipboard: [ClipboardEntry] = []
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
        project.tracks.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }.sorted {
            $0.startInSeconds < $1.startInSeconds
        }
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
        highlightMarks.clear()
    }

    func markHighlightStart() {
        highlightMarks.markStart(at: playheadInSeconds)
    }

    func markHighlightEnd() {
        highlightMarks.markEnd(at: playheadInSeconds)
    }

    func clearHighlightMarks() {
        highlightMarks.clear()
    }

    @discardableResult
    func saveHighlightFromMarks() -> Highlight.ID? {
        guard let range = highlightMarks.range else { return nil }
        let id = addHighlight(from: range.lowerBound, to: range.upperBound)
        highlightMarks.clear()
        return id
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

    func setSelection(_ ids: Set<Clip.ID>, primary: Clip.ID?) {
        selectedClipIDs = ids
        if let primary, ids.contains(primary) {
            selectedClipID = primary
        } else {
            selectedClipID = ids.first
        }
    }

    func setPlayhead(near proposed: TimeInterval) {
        let candidates = project.snapPoints(excluding: nil, playhead: -1)
        let snapped = Snapping.snap(
            max(0, proposed), to: candidates, within: snapThresholdInSeconds)
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
        movePlayhead(
            to: editPoints.first { $0 > playheadInSeconds + tolerance } ?? project.durationInSeconds
        )
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

    private var editPoints: [TimeInterval] {
        Array(Set(project.snapPoints(excluding: nil, playhead: 0))).sorted()
    }

    var snapThresholdInSeconds: TimeInterval {
        guard isSnappingEnabled else { return 0 }
        return Self.snapThresholdInPoints / pointsPerSecond
    }

    func mutate(coalescingKey: String? = nil, _ change: (inout Project) -> Void) {
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
            timestamp.timeIntervalSince(lastMutationDate) <= Self.coalescingWindowInSeconds
        {
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
        pointsPerSecond = min(
            max(proposed, Self.minimumPointsPerSecond), Self.maximumPointsPerSecond)
    }

}
