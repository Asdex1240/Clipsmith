import SwiftUI

struct ContentView: View {
    let store: ProjectStore
    let library: MediaLibrary
    let player: PlayerController
    let previewer: TimelinePreviewer
    let exporter: ExportController
    let highlightExporter: HighlightExportController
    let highlightPreview: HighlightPreviewController
    let subtitles: SubtitleController
    let document: DocumentController
    let documentActions: DocumentActions
    let thumbnails: ThumbnailGenerating
    let waveforms: WaveformStore
    let filmstrips: FilmstripStore
    @State private var selection: MediaItem.ID?
    @State private var isExportPresented = false
    @State private var relinkDismissed = false
    @AppStorage("layout.sidebarVisible") private var isSidebarVisible = true
    @AppStorage("layout.inspectorVisible") private var isInspectorVisible = true

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
                if isSidebarVisible { sidebar }
                PreviewView(
                    controller: player, store: store, proxies: previewer.proxies,
                    highlightPreview: highlightPreview, onSelectTimeline: showTimeline
                )
                .frame(minWidth: Layout.previewMinWidth)
                if isInspectorVisible { inspector }
            }
            Divider()
            TimelineView(
                store: store, library: library, waveforms: waveforms, filmstrips: filmstrips,
                missingMedia: Set(document.missingMedia)
            )
            .frame(height: Layout.timelineHeight)
        }
        .toolbar {
            MainToolbar(
                store: store, documentActions: documentActions,
                isSidebarVisible: $isSidebarVisible, isInspectorVisible: $isInspectorVisible,
                onExport: { isExportPresented = true })
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
            Button(
                localized("recovery.discard"), role: .destructive, action: document.discardRecovery)
        } message: {
            Text(localized("recovery.message"))
        }
        .alert(localized("document.error.title"), isPresented: documentErrorIsPresented) {
            Button(localized("alert.ok")) { document.errorMessage = nil }
        } message: {
            Text(document.errorMessage ?? "")
        }
        .onChange(of: selection, selectionDidChange)
        .onChange(of: store.projectRevision) {
            previewer.projectDidChange()
            highlightPreview.projectDidChange()
        }
        .onChange(of: store.playheadInSeconds) { player.seekTimeline(to: store.playheadInSeconds) }
        .onAppear { player.onTimelineTimeChange = store.followPlayback(at:) }
        .alert(localized("alert.error.title"), isPresented: errorIsPresented) {
            Button(localized("alert.ok"), action: library.dismissError)
        } message: {
            Text(library.lastErrorMessage ?? "")
        }
    }

    private var sidebar: some View {
        SidebarView(
            store: store,
            highlightExporter: highlightExporter,
            highlightPreview: highlightPreview,
            library: library,
            thumbnails: thumbnails,
            waveforms: waveforms,
            selection: $selection,
            onAddToTimeline: store.appendToTimeline
        )
        .frame(minWidth: Layout.libraryMinWidth, idealWidth: Layout.libraryIdealWidth)
        .panelSurface()
    }

    private var inspector: some View {
        InspectorView(
            store: store, subtitles: subtitles, waveforms: waveforms,
            denoise: previewer.denoise
        )
        .frame(minWidth: Layout.inspectorMinWidth, idealWidth: Layout.inspectorIdealWidth)
        .panelSurface()
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

#Preview {
    let store = PreviewFixtures.store()
    let library = MediaLibrary()
    let player = PlayerController()
    let document = PreviewFixtures.document(store: store, library: library)
    ContentView(
        store: store, library: library, player: player,
        previewer: TimelinePreviewer(store: store, player: player),
        exporter: ExportController(store: store),
        highlightExporter: HighlightExportController(store: store),
        highlightPreview: HighlightPreviewController(store: store, player: player),
        subtitles: SubtitleController(store: store),
        document: document, documentActions: DocumentActions(document: document),
        thumbnails: CachedThumbnailGenerator(), waveforms: WaveformStore(),
        filmstrips: FilmstripStore()
    )
    .frame(width: 1280, height: 800)
}
