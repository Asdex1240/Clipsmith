import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class DocumentController {
    static let fileExtension = "clipsmith"
    static let autosaveInterval: Duration = .seconds(30)

    private struct Snapshot: Equatable {
        var project: Project
        var library: [MediaItem]
    }

    private(set) var fileURL: URL?
    private(set) var missingMedia: [URL] = []
    private(set) var recoveryIsAvailable = false
    var errorMessage: String?
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let library: MediaLibrary
    @ObservationIgnored private let storage: ProjectStoring
    @ObservationIgnored private let recovery: RecoveryStore
    @ObservationIgnored private let logger = Logger(subsystem: "Clipsmith", category: "document")
    private var savedSnapshot: Snapshot

    init(
        store: ProjectStore,
        library: MediaLibrary,
        storage: ProjectStoring = ProjectStorage(),
        recovery: RecoveryStore = RecoveryStore()
    ) {
        self.store = store
        self.library = library
        self.storage = storage
        self.recovery = recovery
        self.savedSnapshot = Snapshot(project: store.project, library: library.items)
    }

    var hasUnsavedChanges: Bool {
        currentSnapshot != savedSnapshot
    }

    var windowTitleName: String {
        store.project.name
    }

    var windowTitle: String {
        guard hasUnsavedChanges else { return store.project.name }
        return store.project.name + " — " + localized("document.edited")
    }

    func newProject() {
        apply(Project(name: localized("project.untitled")), library: [], missingMedia: [], fileURL: nil)
        recovery.clear()
    }

    func open(_ url: URL) {
        do {
            let loaded = try storage.read(from: url)
            apply(loaded.project, library: loaded.library, missingMedia: loaded.missingMedia, fileURL: url)
            recovery.clear()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let fileURL else { return false }
        return save(to: fileURL)
    }

    @discardableResult
    func save(to url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent
        let previousName = store.project.name
        store.setProjectName(name)
        do {
            try storage.write(project: store.project, library: library.items, to: url)
        } catch {
            store.setProjectName(previousName)
            errorMessage = error.localizedDescription
            return false
        }
        fileURL = url
        savedSnapshot = currentSnapshot
        recovery.clear()
        return true
    }

    func relink(_ original: URL, to replacement: URL) {
        store.replaceMedia(from: original, to: replacement)
        library.remapSources([original: replacement])
        missingMedia.removeAll { $0 == original }
    }

    func discardChangesForQuit() {
        recovery.clear()
    }

    func checkForRecovery() {
        recoveryIsAvailable = recovery.hasRecovery
    }

    func restoreRecovery() {
        recoveryIsAvailable = false
        do {
            let loaded = try recovery.load()
            apply(loaded.project, library: loaded.library, missingMedia: loaded.missingMedia, fileURL: nil)
            savedSnapshot = Snapshot(project: Project(name: loaded.project.name), library: [])
        } catch {
            errorMessage = error.localizedDescription
        }
        recovery.clear()
    }

    func discardRecovery() {
        recoveryIsAvailable = false
        recovery.clear()
    }

    func autosave() {
        guard hasUnsavedChanges else { return }
        do {
            try recovery.save(project: store.project, library: library.items)
        } catch {
            logger.error("Autosave failed: \(error.localizedDescription)")
        }
    }

    func runAutosaveLoop() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: Self.autosaveInterval)
            } catch {
                return
            }
            autosave()
        }
    }

    private var currentSnapshot: Snapshot {
        Snapshot(project: store.project, library: library.items)
    }

    private func apply(_ project: Project, library items: [MediaItem], missingMedia: [URL], fileURL: URL?) {
        store.load(project)
        library.replaceItems(items)
        self.missingMedia = missingMedia
        self.fileURL = fileURL
        savedSnapshot = currentSnapshot
    }
}
