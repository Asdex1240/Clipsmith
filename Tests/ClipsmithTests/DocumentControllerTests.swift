import XCTest
@testable import Clipsmith

@MainActor
final class DocumentControllerTests: XCTestCase {
    private var directory: URL!
    private var store = ProjectStore(project: Project(name: "Test"))
    private var library = MediaLibrary(loader: NeverLoader())
    private var recovery: RecoveryStore!
    private var document: DocumentController!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = ProjectStore(project: Project(name: "Test"))
        library = MediaLibrary(loader: NeverLoader())
        recovery = RecoveryStore(fileURL: directory.appendingPathComponent("recovery/Recovery.clipsmith"))
        document = DocumentController(store: store, library: library, recovery: recovery)
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testFreshDocumentHasNoUnsavedChanges() {
        XCTAssertFalse(document.hasUnsavedChanges)
        XCTAssertNil(document.fileURL)
    }

    func testEditingMarksTheDocumentAsEditedAndUndoClearsIt() {
        store.setCanvas(.portrait)
        XCTAssertTrue(document.hasUnsavedChanges)
        XCTAssertTrue(document.windowTitle.contains(localized("document.edited")))

        store.undo()
        XCTAssertFalse(document.hasUnsavedChanges)
    }

    func testSaveWritesTheFileNamesTheProjectAndClearsTheEditedState() throws {
        store.setCanvas(.portrait)
        let url = directory.appendingPathComponent("Vlog Roma.clipsmith")

        XCTAssertTrue(document.save(to: url))

        XCTAssertEqual(document.fileURL, url)
        XCTAssertEqual(store.project.name, "Vlog Roma")
        XCTAssertFalse(document.hasUnsavedChanges)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveWithoutAFileDoesNothing() {
        XCTAssertFalse(document.save())
    }

    func testSaveToAnUnwritableLocationReportsTheErrorAndKeepsTheName() {
        let url = directory.appendingPathComponent("missing-folder/x.clipsmith")

        XCTAssertFalse(document.save(to: url))

        XCTAssertNotNil(document.errorMessage)
        XCTAssertEqual(store.project.name, "Test")
        XCTAssertNil(document.fileURL)
    }

    func testOpeningALoadedFileRestoresProjectLibraryAndCleanState() throws {
        let media = directory.appendingPathComponent("clip.mov")
        try Data("m".utf8).write(to: media)
        let item = MediaItem(url: media, kind: .video, durationInSeconds: 8)
        library.replaceItems([item])
        store.appendToTimeline(item)
        let url = directory.appendingPathComponent("a.clipsmith")
        XCTAssertTrue(document.save(to: url))

        document.newProject()
        XCTAssertTrue(store.project.referencedSourceURLs.isEmpty)
        XCTAssertTrue(library.items.isEmpty)

        document.open(url)

        XCTAssertEqual(store.project.referencedSourceURLs.map(\.lastPathComponent), ["clip.mov"])
        XCTAssertEqual(library.items.count, 1)
        XCTAssertFalse(document.hasUnsavedChanges)
        XCTAssertEqual(document.fileURL, url)
        XCTAssertFalse(store.canUndo)
    }

    func testOpeningAnInvalidFileReportsAnErrorAndKeepsTheCurrentProject() throws {
        store.setCanvas(.portrait)
        let url = directory.appendingPathComponent("bad.clipsmith")
        try Data("nope".utf8).write(to: url)

        document.open(url)

        XCTAssertNotNil(document.errorMessage)
        XCTAssertEqual(store.project.canvas, .portrait)
    }

    func testMissingMediaIsListedAndRelinkingFixesProjectAndLibrary() throws {
        let media = directory.appendingPathComponent("clip.mov")
        try Data("m".utf8).write(to: media)
        let item = MediaItem(url: media, kind: .video, durationInSeconds: 8)
        library.replaceItems([item])
        store.appendToTimeline(item)
        let url = directory.appendingPathComponent("a.clipsmith")
        document.save(to: url)
        try FileManager.default.removeItem(at: media)
        document.open(url)
        XCTAssertEqual(document.missingMedia.map(\.lastPathComponent), ["clip.mov"])
        let replacement = directory.appendingPathComponent("found.mov")
        try Data("m".utf8).write(to: replacement)

        document.relink(document.missingMedia[0], to: replacement)

        XCTAssertTrue(document.missingMedia.isEmpty)
        XCTAssertEqual(store.project.referencedSourceURLs, [replacement])
        XCTAssertEqual(library.items.map(\.url), [replacement])
        XCTAssertTrue(document.hasUnsavedChanges)
    }

    func testNewProjectResetsEverything() {
        store.setCanvas(.portrait)
        document.save(to: directory.appendingPathComponent("a.clipsmith"))

        document.newProject()

        XCTAssertNil(document.fileURL)
        XCTAssertFalse(document.hasUnsavedChanges)
        XCTAssertEqual(store.project.name, localized("project.untitled"))
    }

    func testAutosaveOnlyWritesRecoveryWhenThereAreChanges() {
        document.autosave()
        XCTAssertFalse(recovery.hasRecovery)

        store.setCanvas(.portrait)
        document.autosave()

        XCTAssertTrue(recovery.hasRecovery)
    }

    func testSavingRemovesTheRecoveryFile() {
        store.setCanvas(.portrait)
        document.autosave()

        document.save(to: directory.appendingPathComponent("a.clipsmith"))

        XCTAssertFalse(recovery.hasRecovery)
    }

    func testRecoveredProjectComesBackAsUnsavedChanges() {
        store.setCanvas(.portrait)
        store.setProjectName("Draft")
        document.autosave()
        let relaunchedStore = ProjectStore(project: Project(name: "Fresh"))
        let relaunched = DocumentController(store: relaunchedStore, library: MediaLibrary(loader: NeverLoader()), recovery: recovery)

        relaunched.checkForRecovery()
        XCTAssertTrue(relaunched.recoveryIsAvailable)
        relaunched.restoreRecovery()

        XCTAssertEqual(relaunchedStore.project.canvas, .portrait)
        XCTAssertEqual(relaunchedStore.project.name, "Draft")
        XCTAssertTrue(relaunched.hasUnsavedChanges)
        XCTAssertFalse(relaunched.recoveryIsAvailable)
        XCTAssertFalse(recovery.hasRecovery)
    }

    func testDiscardingRecoveryDeletesIt() {
        store.setCanvas(.portrait)
        document.autosave()
        document.checkForRecovery()

        document.discardRecovery()

        XCTAssertFalse(document.recoveryIsAvailable)
        XCTAssertFalse(recovery.hasRecovery)
    }
}

private struct NeverLoader: MediaLoading {
    func loadItem(from url: URL) async throws -> MediaItem {
        throw ImportError.unreadable(url)
    }
}
