import SwiftUI

/// Where a library item would land while it is dragged over a lane.
struct DropPreview: Equatable {
    let trackID: Track.ID
    let start: TimeInterval
    let duration: TimeInterval
    let kind: MediaKind
    let name: String
    let isValid: Bool
}

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
        return DropProposal(operation: preview?.isValid == true ? .copy : .forbidden)
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

    private func update(_ info: DropInfo) {
        guard let item = draggedItem else { return }
        let isValid = track.role.accepts(item.kind)
        let proposed = info.location.x / pointsPerSecond
        let next = DropPreview(
            trackID: track.id,
            start: isValid ? store.dropStart(duration: item.durationInSeconds, on: track, near: proposed) : max(0, proposed),
            duration: item.durationInSeconds,
            kind: item.kind,
            name: item.name,
            isValid: isValid
        )
        if preview != next { preview = next }
    }
}

struct DropGhostView: View {
    let preview: DropPreview
    let pointsPerSecond: Double

    var body: some View {
        let tint: Color = preview.isValid ? .accentColor : .red
        RoundedRectangle(cornerRadius: 6)
            .fill(tint.opacity(0.25))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
            .overlay(alignment: .leading) {
                Label(preview.name, systemImage: preview.isValid ? "plus" : "nosign")
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
            .frame(width: max(preview.duration * pointsPerSecond, 24), height: TimelineMetrics.laneHeight)
            .offset(x: preview.start * pointsPerSecond)
            .allowsHitTesting(false)
    }
}
