import Foundation

@MainActor
enum LiveTextOverlay {
    static func timeline(of store: ProjectStore, in controller: PlayerController) -> TextOverlay? {
        guard let renderSize = controller.timelineOverlay?.renderSize else { return nil }
        let clips = store.project.tracks.filter { $0.role == .text }.flatMap(\.clips)
        return TextOverlay(clips: clips, renderSize: renderSize)
    }
}
