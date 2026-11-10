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

    init(store: ProjectStore, player: PlayerController, builder: CompositionBuilding = CompositionBuilder()) {
        self.store = store
        self.player = player
        self.builder = builder
    }

    func projectDidChange() {
        buildTask?.cancel()
        let project = store.project
        // Text is drawn live by the preview, so text-only edits need no new composition.
        let structure = Self.withoutText(project)
        guard structure != lastBuiltStructure else { return }
        // Moving a clip only changes its transform, which can be swapped in live.
        let isMoveOnly = lastBuiltStructure.map { Self.withoutTransforms(structure) == Self.withoutTransforms($0) } ?? false
        buildTask = Task {
            if !isMoveOnly {
                do {
                    try await Task.sleep(for: Self.debounce)
                } catch {
                    return
                }
            }
            await rebuild(project, moveOnly: isMoveOnly)
        }
    }

    private static func withoutText(_ project: Project) -> Project {
        var copy = project
        for index in copy.tracks.indices where copy.tracks[index].role == .text {
            copy.tracks[index].clips = []
        }
        return copy
    }

    private static func withoutTransforms(_ project: Project) -> Project {
        var copy = project
        for track in copy.tracks.indices {
            for clip in copy.tracks[track].clips.indices {
                copy.tracks[track].clips[clip].offsetX = 0
                copy.tracks[track].clips[clip].offsetY = 0
                copy.tracks[track].clips[clip].scale = 1
                copy.tracks[track].clips[clip].rotationInDegrees = 0
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
