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
