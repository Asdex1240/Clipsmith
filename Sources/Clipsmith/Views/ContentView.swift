import SwiftUI

struct ContentView: View {
    let store: ProjectStore
    let library: MediaLibrary
    let player: PlayerController
    let previewer: TimelinePreviewer
    let exporter: ExportController
    let document: DocumentController
    let documentActions: DocumentActions
    let thumbnails: ThumbnailGenerating
    let waveforms: WaveformStore
    @State private var selection: MediaItem.ID?
    @State private var isExportPresented = false
    @State private var relinkDismissed = false

    private enum Layout {
        static let libraryMinWidth: CGFloat = 220
        static let libraryIdealWidth: CGFloat = 280
        static let previewMinWidth: CGFloat = 400
        static let inspectorMinWidth: CGFloat = 200
        static let inspectorIdealWidth: CGFloat = 260
        static let timelineHeight: CGFloat = 280
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
                InspectorView(store: store)
                    .frame(minWidth: Layout.inspectorMinWidth, idealWidth: Layout.inspectorIdealWidth)
            }
            Divider()
            TimelineView(store: store, library: library, waveforms: waveforms, missingMedia: Set(document.missingMedia))
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
        .sheet(isPresented: relinkIsPresented) {
            RelinkView(document: document, actions: documentActions) { relinkDismissed = true }
        }
        .navigationTitle(document.windowTitle)
        .task { document.checkForRecovery() }
        .task { await document.runAutosaveLoop() }
        .onChange(of: document.missingMedia) { relinkDismissed = false }
        .alert(localized("recovery.title"), isPresented: recoveryIsPresented) {
            Button(localized("recovery.restore"), action: document.restoreRecovery)
            Button(localized("recovery.discard"), role: .destructive, action: document.discardRecovery)
        } message: {
            Text(localized("recovery.message"))
        }
        .alert(localized("document.error.title"), isPresented: documentErrorIsPresented) {
            Button(localized("alert.ok")) { document.errorMessage = nil }
        } message: {
            Text(document.errorMessage ?? "")
        }
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

    private var relinkIsPresented: Binding<Bool> {
        Binding(
            get: { !document.missingMedia.isEmpty && !relinkDismissed },
            set: { if !$0 { relinkDismissed = true } }
        )
    }

    private var recoveryIsPresented: Binding<Bool> {
        Binding(
            get: { document.recoveryIsAvailable },
            set: { if !$0 { document.discardRecovery() } }
        )
    }

    private var documentErrorIsPresented: Binding<Bool> {
        Binding(
            get: { document.errorMessage != nil },
            set: { if !$0 { document.errorMessage = nil } }
        )
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
}
