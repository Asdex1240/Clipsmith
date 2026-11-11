import SwiftUI

struct LaneDropDelegate: DropDelegate {
    let track: Track
    let store: ProjectStore
    let library: MediaLibrary
    let pointsPerSecond: Double
    @Binding var preview: DropPreview?

    private var draggedItem: MediaItem? {
        library.draggedItemID.flatMap { id in library.items.first { $0.id == id } }
    }

    func validateDrop(info: DropInfo) -> Bool { draggedItem != nil }

    func dropEntered(info: DropInfo) { update(info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        update(info)
        guard preview?.isValid == true else { return DropProposal(operation: .forbidden) }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        if preview?.trackID == track.id { preview = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            preview = nil
            library.draggedItemID = nil
        }
        guard let item = draggedItem, track.role.accepts(item.kind) else { return false }
        store.addMedia(item, toTrack: track.id, at: info.location.x / pointsPerSecond)
        return true
    }

    private func startTime(for item: MediaItem, proposed: TimeInterval) -> TimeInterval {
        guard track.role.accepts(item.kind) else { return max(0, proposed) }
        return store.dropStart(duration: item.durationInSeconds, on: track, near: proposed)
    }

    private func update(_ info: DropInfo) {
        guard let item = draggedItem else { return }
        let isValid = track.role.accepts(item.kind)
        let proposed = info.location.x / pointsPerSecond
        let next = DropPreview(
            trackID: track.id,
            start: startTime(for: item, proposed: proposed),
            duration: item.durationInSeconds,
            kind: item.kind,
            name: item.name,
            isValid: isValid
        )
        if preview != next { preview = next }
    }
}
