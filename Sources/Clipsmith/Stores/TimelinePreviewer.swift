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

    init(store: ProjectStore, player: PlayerController, builder: CompositionBuilding = CompositionBuilder()) {
        self.store = store
        self.player = player
        self.builder = builder
    }

    func projectDidChange() {
        buildTask?.cancel()
        let project = store.project
        buildTask = Task {
            do {
                try await Task.sleep(for: Self.debounce)
            } catch {
                return
            }
            await rebuild(project)
        }
    }

    private func rebuild(_ project: Project) async {
        do {
            let built = try await builder.build(from: project)
            guard !Task.isCancelled else { return }
            player.setTimeline(built.durationInSeconds > 0 ? built : nil, at: store.playheadInSeconds)
        } catch {
            logger.error("Could not build the preview: \(error.localizedDescription)")
        }
    }
}
