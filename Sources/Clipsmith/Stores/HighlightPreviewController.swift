import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class HighlightPreviewController {
    private static let debounce: Duration = .milliseconds(150)

    private(set) var requestedID: Highlight.ID?
    private(set) var isBuilding = false
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let player: PlayerController
    @ObservationIgnored private let builder: CompositionBuilding
    @ObservationIgnored private let proxies: ProxyStore?
    @ObservationIgnored private let denoise: DenoiseStore?
    @ObservationIgnored private let settings: PreviewSettings?
    @ObservationIgnored private let logger = Logger(subsystem: "Clipsmith", category: "highlight")
    @ObservationIgnored private var buildTask: Task<Void, Never>?

    init(
        store: ProjectStore, player: PlayerController,
        builder: CompositionBuilding = CompositionBuilder(), proxies: ProxyStore? = nil,
        denoise: DenoiseStore? = nil, settings: PreviewSettings? = nil
    ) {
        self.store = store
        self.player = player
        self.builder = builder
        self.proxies = proxies
        self.denoise = denoise
        self.settings = settings
    }

    var activeHighlight: Highlight? {
        guard let requestedID else { return nil }
        return store.project.highlight(withID: requestedID)
    }

    func isShowing(_ id: Highlight.ID) -> Bool {
        requestedID == id && (isBuilding || player.mode == .highlight)
    }

    func show(_ id: Highlight.ID) {
        guard store.project.highlight(withID: id) != nil else { return }
        requestedID = id
        isBuilding = true
        scheduleBuild(debounced: .no)
    }

    func close() {
        guard requestedID != nil else { return }
        buildTask?.cancel()
        requestedID = nil
        isBuilding = false
        guard player.mode == .highlight else { return }
        player.showTimeline(at: store.playheadInSeconds)
    }

    func projectDidChange() {
        guard requestedID != nil else { return }
        guard player.mode == .highlight || isBuilding else {
            requestedID = nil
            return
        }
        guard activeHighlight != nil else {
            close()
            return
        }
        scheduleBuild(debounced: .yes)
    }

    private enum Debounce { case yes, no }

    private func scheduleBuild(debounced: Debounce) {
        buildTask?.cancel()
        buildTask = Task {
            if debounced == .yes {
                do {
                    try await Task.sleep(for: Self.debounce)
                } catch {
                    return
                }
            }
            await rebuild()
        }
    }

    private func rebuild() async {
        guard let highlight = activeHighlight else { return }
        var derived = store.project.extracting(highlight)
        if let denoise { derived = denoise.applying(derived) }
        if let proxies { derived = proxies.substituting(derived) }
        do {
            let quality = settings?.quality ?? .full
            let built = try await builder.build(
                from: derived, renderSize: quality.renderSize(for: derived.canvas),
                framesPerSecond: CompositionBuilder.previewFramesPerSecond)
            guard !Task.isCancelled, requestedID == highlight.id else { return }
            isBuilding = false
            if built.durationInSeconds > 0 {
                player.showHighlight(built)
            } else {
                player.showHighlight(nil)
            }
        } catch {
            logger.error("Could not build the highlight preview: \(error.localizedDescription)")
        }
    }
}
