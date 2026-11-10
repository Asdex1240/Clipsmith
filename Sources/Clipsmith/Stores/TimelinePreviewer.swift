import Foundation
import OSLog

@MainActor
final class TimelinePreviewer {
    private static let debounce: Duration = .milliseconds(150)

    private let store: ProjectStore
    private let player: PlayerController
    private let builder: CompositionBuilding
    private let logger = Logger(subsystem: "Clipsmith", category: "preview")
    private var buildTask: Task<Void, Never>?
    private var lastBuiltStructure: Project?
    private var liveTask: Task<Void, Never>?
    private var pendingLiveProject: Project?

    init(store: ProjectStore, player: PlayerController, builder: CompositionBuilding = CompositionBuilder()) {
        self.store = store
        self.player = player
        self.builder = builder
    }

    func projectDidChange() {
        let project = store.project
        // Text is drawn live by the preview, so text-only edits need no new composition.
        let structure = Self.withoutText(project)
        guard structure != lastBuiltStructure else { return }
        // Moving a clip or changing its look only changes how frames are drawn, which can be swapped in live.
        let isLiveEdit = lastBuiltStructure.map { Self.withoutLook(structure) == Self.withoutLook($0) } ?? false
        if isLiveEdit {
            applyLive(project)
            return
        }
        buildTask?.cancel()
        liveTask?.cancel()
        liveTask = nil
        pendingLiveProject = nil
        buildTask = Task {
            do {
                try await Task.sleep(for: Self.debounce)
            } catch {
                return
            }
            await rebuild(project, moveOnly: false)
        }
    }

    /// Keeps the preview following a slider or a drag: it never waits for the edit to stop, and while one
    /// update is being prepared only the latest later state is kept, so the picture changes as fast as it can be built.
    private func applyLive(_ project: Project) {
        pendingLiveProject = project
        guard liveTask == nil else { return }
        liveTask = Task {
            while let next = pendingLiveProject, !Task.isCancelled {
                pendingLiveProject = nil
                await rebuild(next, moveOnly: true)
            }
            // A cancelled loop was already replaced by whoever cancelled it.
            if !Task.isCancelled { liveTask = nil }
        }
    }

    private static func withoutText(_ project: Project) -> Project {
        var copy = project
        // Markers and the name do not affect what is played, so changing them must not rebuild the preview.
        copy.markers = []
        copy.name = ""
        for index in copy.tracks.indices where copy.tracks[index].role == .text {
            copy.tracks[index].clips = []
        }
        return copy
    }

    private static func withoutLook(_ project: Project) -> Project {
        var copy = project
        for track in copy.tracks.indices {
            for clip in copy.tracks[track].clips.indices {
                copy.tracks[track].clips[clip].offsetX = 0
                copy.tracks[track].clips[clip].offsetY = 0
                copy.tracks[track].clips[clip].scale = 1
                copy.tracks[track].clips[clip].rotationInDegrees = 0
                copy.tracks[track].clips[clip].opacity = 1
                copy.tracks[track].clips[clip].keyframes = []
                copy.tracks[track].clips[clip].color = ColorAdjustments()
                copy.tracks[track].clips[clip].crop = CropInsets()
            }
        }
        return copy
    }

    private func rebuild(_ project: Project, moveOnly: Bool) async {
        do {
            let built = try await builder.build(from: project)
            guard !Task.isCancelled else { return }
            lastBuiltStructure = Self.withoutText(project)
            if moveOnly, built.durationInSeconds > 0 {
                player.updateTransforms(built)
            } else {
                player.setTimeline(built.durationInSeconds > 0 ? built : nil, at: store.playheadInSeconds)
            }
        } catch {
            logger.error("Could not build the preview: \(error.localizedDescription)")
        }
    }
}
