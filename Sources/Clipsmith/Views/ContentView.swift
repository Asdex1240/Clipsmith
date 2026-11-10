import SwiftUI

struct ContentView: View {
    let store: ProjectStore
    let library: MediaLibrary
    let player: PlayerController
    let previewer: TimelinePreviewer
    let exporter: ExportController
    let thumbnails: ThumbnailGenerating
    @State private var selection: MediaItem.ID?
    @State private var isExportPresented = false

    private enum Layout {
        static let libraryMinWidth: CGFloat = 220
        static let libraryIdealWidth: CGFloat = 280
        static let previewMinWidth: CGFloat = 400
        static let inspectorMinWidth: CGFloat = 200
        static let inspectorIdealWidth: CGFloat = 260
        static let timelineHeight: CGFloat = 270
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                LibraryView(
                    library: library,
                    thumbnails: thumbnails,
                    selection: $selection,
                    onAddToTimeline: store.appendToTimeline
                )
                    .frame(minWidth: Layout.libraryMinWidth, idealWidth: Layout.libraryIdealWidth)
                PreviewView(controller: player, store: store, onSelectTimeline: showTimeline)
                    .frame(minWidth: Layout.previewMinWidth)
                placeholder(localized("panel.inspector"))
                    .frame(minWidth: Layout.inspectorMinWidth, idealWidth: Layout.inspectorIdealWidth)
            }
            Divider()
            TimelineView(store: store, library: library)
                .frame(height: Layout.timelineHeight)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(localized("export.open"), systemImage: "square.and.arrow.up") { isExportPresented = true }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(store.project.durationInSeconds == 0)
            }
        }
        .sheet(isPresented: $isExportPresented) { ExportView(controller: exporter) }
        .onChange(of: selection, selectionDidChange)
        .onChange(of: store.projectRevision) { previewer.projectDidChange() }
        .onChange(of: store.playheadInSeconds) { player.seekTimeline(to: store.playheadInSeconds) }
        .onAppear { player.onTimelineTimeChange = store.followPlayback(at:) }
        .alert(localized("alert.error.title"), isPresented: errorIsPresented) {
            Button(localized("alert.ok"), action: library.dismissError)
        } message: {
            Text(library.lastErrorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { library.lastErrorMessage != nil },
            set: { if !$0 { library.dismissError() } }
        )
    }

    private func selectionDidChange() {
        guard let item = library.items.first(where: { $0.id == selection }) else { return }
        player.showSource(item)
    }

    private func showTimeline() {
        player.showTimeline(at: store.playheadInSeconds)
    }

    private func placeholder(_ title: String) -> some View {
        ZStack {
            Rectangle().fill(.background.secondary)
            Text(title).foregroundStyle(.secondary)
        }
    }
}
