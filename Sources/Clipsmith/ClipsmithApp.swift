import SwiftUI

@main
struct ClipsmithApp: App {
    @NSApplicationDelegateAdaptor(DockActivatingAppDelegate.self) private var appDelegate
    @State private var store: ProjectStore
    @State private var library: MediaLibrary
    @State private var player: PlayerController
    @State private var previewer: TimelinePreviewer
    @State private var exporter: ExportController
    @State private var document: DocumentController
    private let documentActions: DocumentActions
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
        _player = State(initialValue: player)
        _previewer = State(initialValue: TimelinePreviewer(store: store, player: player))
        _exporter = State(initialValue: ExportController(store: store))
    }

    var body: some Scene {
        WindowGroup("Clipsmith") {
            ContentView(store: store, library: library, player: player, previewer: previewer, exporter: exporter, document: document,
                documentActions: documentActions, thumbnails: thumbnails, waveforms: waveforms)
                .frame(minWidth: 1100, minHeight: 700)
                .onAppear { appDelegate.shouldAllowTermination = documentActions.confirmDiscardingChanges }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(localized("menu.new")) { documentActions.newProject() }.keyboardShortcut("n")
                Button(localized("menu.open")) { documentActions.openProject() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button(localized("menu.save")) { documentActions.save() }.keyboardShortcut("s")
                Button(localized("menu.saveAs")) { documentActions.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
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
    }
}

final class DockActivatingAppDelegate: NSObject, NSApplicationDelegate {
    var shouldAllowTermination: (() -> Bool)?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        (shouldAllowTermination?() ?? true) ? .terminateNow : .terminateCancel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
