import SwiftUI

struct MarkerFlags: View {
    let store: ProjectStore
    let pointsPerSecond: Double

    private static let flagWidth: CGFloat = 12
    private static let flagHeight: CGFloat = 14
    private static let popoverWidth: CGFloat = 220
    private static let color = Palette.marker

    @State private var editingID: Marker.ID?

    private func displayName(of marker: Marker) -> String {
        if marker.name.isEmpty { return localized("marker.default") }
        return marker.name
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(store.project.markers) { marker in
                flag(for: marker)
            }
        }
        .frame(height: TimelineMetrics.rulerHeight, alignment: .topLeading)
    }

    private func flag(for marker: Marker) -> some View {
        let x = marker.timeInSeconds * pointsPerSecond
        return HStack(spacing: 3) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(Self.color)
                .frame(width: Self.flagWidth, height: Self.flagHeight)
            if !marker.name.isEmpty {
                Text(marker.name).font(.caption2).foregroundStyle(Self.color).lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .help(displayName(of: marker))
        .accessibilityLabel(displayName(of: marker))
        .offset(x: x - Self.flagWidth / 2, y: TimelineMetrics.rulerHeight - Self.flagHeight)
        .onTapGesture(count: 2) { editingID = marker.id }
        .onTapGesture { store.setPlayhead(near: marker.timeInSeconds) }
        .popover(isPresented: editingBinding(for: marker.id), arrowEdge: .bottom) {
            editor(for: marker)
        }
    }

    private func editor(for marker: Marker) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            Text(localized("marker.title")).font(.headline)
            TextField(localized("marker.name"), text: nameBinding(for: marker))
                .textFieldStyle(.roundedBorder)
                .onSubmit { editingID = nil }
            Button(localized("marker.delete"), role: .destructive) {
                editingID = nil
                store.removeMarker(marker.id)
            }
        }
        .padding(14)
        .frame(width: Self.popoverWidth)
    }

    private func editingBinding(for id: Marker.ID) -> Binding<Bool> {
        Binding(get: { editingID == id }, set: { if !$0, editingID == id { editingID = nil } })
    }

    private func nameBinding(for marker: Marker) -> Binding<String> {
        Binding(get: { marker.name }, set: { store.renameMarker(marker.id, to: $0) })
    }
}

#Preview {
    MarkerFlags(store: PreviewFixtures.store(), pointsPerSecond: 40)
        .frame(width: 320)
}
