import SwiftUI

@main
struct ClipsmithApp: App {
    @NSApplicationDelegateAdaptor(DockActivatingAppDelegate.self) private var appDelegate
    @State private var store: ProjectStore
    @State private var library: MediaLibrary
    @State private var player: PlayerController
    @State private var previewer: TimelinePreviewer
    @State private var exporter: ExportController
    @State private var highlightExporter: HighlightExportController
    @State private var subtitles: SubtitleController
    @State private var caches: CacheController
    @State private var document: DocumentController
    private let documentActions: DocumentActions
    private let shortcutMonitor: KeyboardShortcutMonitor
    @State private var isShortcutsPresented = false
    @State private var waveforms = WaveformStore()
    private let thumbnails = CachedThumbnailGenerator()

    init() {
        let store = ProjectStore(project: Project(name: localized("project.untitled")))
        let player = PlayerController()
        let library = MediaLibrary()
        let document = DocumentController(store: store, library: library)
        _store = State(initialValue: store)
        _library = State(initialValue: library)
        _document = State(initialValue: document)
        documentActions = DocumentActions(document: document)
        let runner = EditorShortcutRunner(store: store, player: player)
        shortcutMonitor = KeyboardShortcutMonitor(perform: runner.perform)
        _player = State(initialValue: player)
        let previewer = TimelinePreviewer(store: store, player: player)
        _previewer = State(initialValue: previewer)
        _caches = State(
            initialValue: CacheController(
                proxies: previewer.proxies, denoise: previewer.denoise,
                onCleared: previewer.cachesWereCleared))
        Task.detached(priority: .utility) { CacheCleaner.standard.clean() }
        _exporter = State(initialValue: ExportController(store: store))
        _highlightExporter = State(initialValue: HighlightExportController(store: store))
        _subtitles = State(initialValue: SubtitleController(store: store))
    }

    var body: some Scene {
        WindowGroup("Clipsmith") {
            ContentView(
                store: store, library: library, player: player, previewer: previewer,
                exporter: exporter, highlightExporter: highlightExporter, subtitles: subtitles,
                document: document,
                documentActions: documentActions, thumbnails: thumbnails, waveforms: waveforms
            )
            .frame(minWidth: 1100, minHeight: 700)
            .onAppear {
                appDelegate.shouldAllowTermination = documentActions.confirmDiscardingChanges
                shortcutMonitor.start()
            }
            .sheet(isPresented: $isShortcutsPresented) { ShortcutsView() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(localized("menu.new")) { documentActions.newProject() }.keyboardShortcut("n")
                Button(localized("menu.open")) { documentActions.openProject() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button(localized("menu.save")) { documentActions.save() }.keyboardShortcut("s")
                Button(localized("menu.saveAs")) { documentActions.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button(localized("menu.shortcuts")) { isShortcutsPresented = true }
                    .keyboardShortcut("/")
            }
            CommandGroup(replacing: .undoRedo) {
                Button(localized("menu.undo"), action: store.undo)
                    .keyboardShortcut("z")
                    .disabled(!store.canUndo)
                Button(localized("menu.redo"), action: store.redo)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!store.canRedo)
            }
        }
        Settings { CacheSettingsView(controller: caches) }
    }
}
