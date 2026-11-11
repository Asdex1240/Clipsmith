import SwiftUI

struct DropPreview: Equatable {
    let trackID: Track.ID
    let start: TimeInterval
    let duration: TimeInterval
    let kind: MediaKind
    let name: String
    let isValid: Bool

    var tint: Color {
        if isValid { return .accentColor }
        return .red
    }

    var iconName: String {
        if isValid { return "plus" }
        return "nosign"
    }
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

struct DropGhostView: View {
    let preview: DropPreview
    let pointsPerSecond: Double

    var body: some View {
        let tint = preview.tint
        RoundedRectangle(cornerRadius: 6)
            .fill(tint.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(
                    tint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            )
            .overlay(alignment: .leading) {
                Label(preview.name, systemImage: preview.iconName)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
            .frame(
                width: max(preview.duration * pointsPerSecond, 24),
                height: TimelineMetrics.laneHeight
            )
            .offset(x: preview.start * pointsPerSecond)
            .allowsHitTesting(false)
    }
}

#Preview {
    DropGhostView(
        preview: DropPreview(
            trackID: UUID(), start: 0, duration: 4, kind: .video, name: "sample.mov", isValid: true
        ),
        pointsPerSecond: 40
    )
    .frame(height: 48)
    .padding()
}
