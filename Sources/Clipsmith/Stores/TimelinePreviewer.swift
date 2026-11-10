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
        guard Self.withoutText(project) != lastBuiltStructure else { return }
        buildTask = Task {
            do {
                try await Task.sleep(for: Self.debounce)
            } catch {
                return
            }
            await rebuild(project)
        }
    }

    private static func withoutText(_ project: Project) -> Project {
        var copy = project
        for index in copy.tracks.indices where copy.tracks[index].role == .text {
            copy.tracks[index].clips = []
        }
        return copy
    }

    private func rebuild(_ project: Project) async {
        do {
            let built = try await builder.build(from: project)
            guard !Task.isCancelled else { return }
            lastBuiltStructure = Self.withoutText(project)
            player.setTimeline(built.durationInSeconds > 0 ? built : nil, at: store.playheadInSeconds)
        } catch {
            logger.error("Could not build the preview: \(error.localizedDescription)")
        }
    }
}
