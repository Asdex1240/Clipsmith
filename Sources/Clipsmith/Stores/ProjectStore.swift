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

    private(set) var project: Project {
        didSet { projectRevision += 1 }
    }
    private(set) var projectRevision = 0
    private(set) var selectedClipID: Clip.ID?
    private(set) var playheadInSeconds: TimeInterval = 0
    private(set) var pointsPerSecond = ProjectStore.defaultPointsPerSecond

    init(project: Project) {
        self.project = project
    }

    var selectedClip: Clip? {
        selectedClipID.flatMap { project.clip(withID: $0) }
    }

    func selectClip(_ id: Clip.ID?) {
        selectedClipID = id
    }

    func setPlayhead(near proposed: TimeInterval) {
        let candidates = project.snapPoints(excluding: nil, playhead: -1)
        let snapped = Snapping.snap(max(0, proposed), to: candidates, within: snapThresholdInSeconds)
        playheadInSeconds = max(0, snapped)
    }

    func addTextAtPlayhead() {
        let layer = TextLayer(content: localized("text.default"))
        if let id = project.addTextClip(layer, at: playheadInSeconds, duration: Self.defaultTextDurationInSeconds) {
            selectedClipID = id
        }
    }

    func updateTextLayer(of id: Clip.ID, _ change: (inout TextLayer) -> Void) {
        project.updateTextLayer(of: id, change)
    }

    func setVolume(of id: Clip.ID, to value: Double) {
        project.setVolume(of: id, to: value)
    }

    func setFadeIn(of id: Clip.ID, to seconds: TimeInterval) {
        project.setFadeIn(of: id, to: seconds)
    }

    func setFadeOut(of id: Clip.ID, to seconds: TimeInterval) {
        project.setFadeOut(of: id, to: seconds)
    }

    func followPlayback(at time: TimeInterval) {
        playheadInSeconds = max(0, time)
    }

    func setCanvas(_ format: CanvasFormat) {
        project.canvas = format
    }

    func zoomIn() {
        setZoom(pointsPerSecond * Self.zoomFactor)
    }

    func zoomOut() {
        setZoom(pointsPerSecond / Self.zoomFactor)
    }

    func appendToTimeline(_ item: MediaItem) {
        let role = Track.Role.preferred(for: item.kind)
        guard let track = project.track(withRole: role) else { return }
        addMedia(item, toTrack: track.id, at: track.endInSeconds)
    }

    func addMedia(_ item: MediaItem, toTrack trackID: Track.ID, at proposedStart: TimeInterval) {
        let clip = Clip(item: item, startInSeconds: snappedStart(proposedStart, duration: item.durationInSeconds, excluding: nil))
        if project.addClip(clip, toTrack: trackID) {
            selectedClipID = clip.id
        }
    }

    func moveClip(_ id: Clip.ID, toTrack trackID: Track.ID, near proposedStart: TimeInterval) {
        guard let clip = project.clip(withID: id) else { return }
        let start = snappedStart(proposedStart, duration: clip.durationInSeconds, excluding: id)
        project.moveClip(id, toTrack: trackID, startingAt: start)
    }

    func trimClip(_ id: Clip.ID, edge: ClipEdge, near proposedTime: TimeInterval) {
        let candidates = project.snapPoints(excluding: id, playhead: playheadInSeconds)
        let time = Snapping.snap(proposedTime, to: candidates, within: snapThresholdInSeconds)
        project.trimClip(id, edge: edge, to: time)
    }

    func splitAtPlayhead() {
        for id in splitTargetIDs() {
            project.splitClip(id, at: playheadInSeconds)
        }
    }

    func deleteSelectedClip() {
        guard let id = selectedClipID else { return }
        project.deleteClip(id)
        selectedClipID = nil
    }

    func rippleDeleteSelectedClip() {
        guard let id = selectedClipID else { return }
        project.rippleDeleteClip(id)
        selectedClipID = nil
    }

    private var snapThresholdInSeconds: TimeInterval {
        Self.snapThresholdInPoints / pointsPerSecond
    }

    private func setZoom(_ proposed: Double) {
        pointsPerSecond = min(max(proposed, Self.minimumPointsPerSecond), Self.maximumPointsPerSecond)
    }

    private func snappedStart(_ proposed: TimeInterval, duration: TimeInterval, excluding id: Clip.ID?) -> TimeInterval {
        let candidates = project.snapPoints(excluding: id, playhead: playheadInSeconds)
        return Snapping.snapStart(max(0, proposed), duration: duration, to: candidates, within: snapThresholdInSeconds)
    }

    private func splitTargetIDs() -> [Clip.ID] {
        if let selectedClip {
            return [selectedClip.id]
        }
        return project.tracks.flatMap(\.clips)
            .filter { $0.startInSeconds < playheadInSeconds && playheadInSeconds < $0.endInSeconds }
            .map(\.id)
    }
}
