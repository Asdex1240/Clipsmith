import Foundation
import OSLog

private enum RebuildMode {
    case full, transformsOnly
}

@MainActor
final class TimelinePreviewer {
    private static let debounce: Duration = .milliseconds(150)

    private let store: ProjectStore
    private let player: PlayerController
    private let builder: CompositionBuilding
    let proxies: ProxyStore
    let denoise: DenoiseStore
    private let logger = Logger(subsystem: "Clipsmith", category: "preview")
    private var buildTask: Task<Void, Never>?
    private var lastBuiltStructure: Project?
    private var liveTask: Task<Void, Never>?
    private var pendingLiveProject: Project?

    init(
        store: ProjectStore, player: PlayerController,
        builder: CompositionBuilding = CompositionBuilder(), proxies: ProxyStore? = nil,
        denoise: DenoiseStore? = nil
    ) {
        self.store = store
        self.player = player
        self.builder = builder
        let proxies = proxies ?? ProxyStore()
        self.proxies = proxies
        let denoise = denoise ?? DenoiseStore()
        self.denoise = denoise
        proxies.onChange = { [weak self] in self?.proxiesDidChange() }
        denoise.onChange = { [weak self] in self?.proxiesDidChange() }
    }

    private func proxiesDidChange() {
        scheduleFullRebuild(of: store.project)
    }

    func projectDidChange() {
        let project = store.project
        proxies.prepare(for: project)
        denoise.prepare(for: project)
        let structure = Self.withoutText(project)
        guard structure != lastBuiltStructure else { return }
        let isLiveEdit =
            lastBuiltStructure.map { Self.withoutLook(structure) == Self.withoutLook($0) } ?? false
        if isLiveEdit {
            applyLive(project)
            return
        }
        scheduleFullRebuild(of: project)
    }

    private func scheduleFullRebuild(of project: Project) {
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
            await rebuild(project, mode: .full)
        }
    }

    private func applyLive(_ project: Project) {
        pendingLiveProject = project
        guard liveTask == nil else { return }
        liveTask = Task {
            while let next = pendingLiveProject, !Task.isCancelled {
                pendingLiveProject = nil
                await rebuild(next, mode: .transformsOnly)
            }
            if !Task.isCancelled { liveTask = nil }
        }
    }

    private static func withoutText(_ project: Project) -> Project {
        var copy = project
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

    private func rebuild(_ project: Project, mode: RebuildMode) async {
        do {
            let built = try await builder.build(from: proxies.substituting(denoise.applying(project)))
            guard !Task.isCancelled else { return }
            lastBuiltStructure = Self.withoutText(project)
            if built.durationInSeconds > 0 {
                switch mode {
                case .transformsOnly: player.updateTransforms(built)
                case .full: player.setTimeline(built, at: store.playheadInSeconds)
                }
            } else {
                player.setTimeline(nil, at: store.playheadInSeconds)
            }
        } catch {
            logger.error("Could not build the preview: \(error.localizedDescription)")
        }
    }
}
