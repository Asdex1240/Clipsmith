import XCTest
@testable import Clipsmith

@MainActor
final class MediaLibraryTests: XCTestCase {
    func testImportAddsLoadedItems() async {
        let library = MediaLibrary(loader: StubLoader())

        await library.importMedia(from: [url("a.mp4"), url("b.mp4")])

        XCTAssertEqual(library.items.map(\.name), ["a.mp4", "b.mp4"])
        XCTAssertNil(library.lastErrorMessage)
    }

    func testImportingTheSameFileTwiceKeepsOneItem() async {
        let library = MediaLibrary(loader: StubLoader())

        await library.importMedia(from: [url("a.mp4")])
        await library.importMedia(from: [url("a.mp4")])

        XCTAssertEqual(library.items.count, 1)
    }

    func testFailedImportReportsErrorAndKeepsOtherItems() async {
        let library = MediaLibrary(loader: StubLoader(failing: ["bad.txt"]))

        await library.importMedia(from: [url("bad.txt"), url("good.mp4")])

        XCTAssertEqual(library.items.map(\.name), ["good.mp4"])
        XCTAssertNotNil(library.lastErrorMessage)
    }

    func testDismissErrorClearsMessage() async {
        let library = MediaLibrary(loader: StubLoader(failing: ["bad.txt"]))
        await library.importMedia(from: [url("bad.txt")])

        library.dismissError()

        XCTAssertNil(library.lastErrorMessage)
    }

    func testRemovingAnItemKeepsTheOthers() async {
        let library = MediaLibrary(loader: StubLoader())
        await library.importMedia(from: [url("a.mp4"), url("b.mp4")])
        let first = library.items[0]

        library.removeItem(first.id)

        XCTAssertEqual(library.items.map(\.name), ["b.mp4"])
    }

    func testRemovedFilesCanBeImportedAgain() async {
        let library = MediaLibrary(loader: StubLoader())
        await library.importMedia(from: [url("a.mp4")])

        library.removeItem(library.items[0].id)
        await library.importMedia(from: [url("a.mp4")])

        XCTAssertEqual(library.items.map(\.name), ["a.mp4"])
    }

    func testUndoPutsARemovedItemBackInItsPlace() async {
        let library = MediaLibrary(loader: StubLoader())
        await library.importMedia(from: [url("a.mp4"), url("b.mp4"), url("c.mp4")])
        let store = ProjectStore(project: Project(name: "Undo"))

        store.remove(library.items[1], from: library)
        store.undo()

        XCTAssertEqual(library.items.map(\.name), ["a.mp4", "b.mp4", "c.mp4"])
    }

    func testRedoRemovesTheItemAgain() async {
        let library = MediaLibrary(loader: StubLoader())
        await library.importMedia(from: [url("a.mp4"), url("b.mp4")])
        let store = ProjectStore(project: Project(name: "Redo"))
        store.remove(library.items[0], from: library)

        store.undo()
        store.redo()

        XCTAssertEqual(library.items.map(\.name), ["b.mp4"])
    }

    func testUndoFollowsTheOrderOfLibraryAndTimelineChanges() async {
        let library = MediaLibrary(loader: StubLoader())
        await library.importMedia(from: [url("a.mp4")])
        let store = ProjectStore(project: Project(name: "Order"))
        store.remove(library.items[0], from: library)
        store.mutate { $0.tracks[0].clips = [TestClips.video(start: 0)] }

        store.undo()

        XCTAssertEqual(store.project.tracks[0].clips, [])
        XCTAssertEqual(library.items.map(\.name), [])

        store.undo()

        XCTAssertEqual(library.items.map(\.name), ["a.mp4"])
        XCTAssertFalse(store.canUndo)
    }

    func testUndoDoesNotDuplicateAFileImportedAgain() async {
        let library = MediaLibrary(loader: StubLoader())
        await library.importMedia(from: [url("a.mp4")])
        let store = ProjectStore(project: Project(name: "Again"))
        store.remove(library.items[0], from: library)
        await library.importMedia(from: [url("a.mp4")])

        store.undo()

        XCTAssertEqual(library.items.map(\.name), ["a.mp4"])
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}

private struct StubLoader: MediaLoading {
    var failing: Set<String> = []

    func loadItem(from url: URL) async throws -> MediaItem {
        if failing.contains(url.lastPathComponent) {
            throw ImportError.unsupportedFormat(url)
        }
        return MediaItem(url: url, kind: .video, durationInSeconds: 10)
    }
}
