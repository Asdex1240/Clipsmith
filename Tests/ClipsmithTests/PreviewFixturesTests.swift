import XCTest

@testable import Clipsmith

@MainActor
final class PreviewFixturesTests: XCTestCase {
    func testStoreHasVideoAndTextClipsWithVideoSelected() {
        let store = PreviewFixtures.store()

        XCTAssertNotNil(store.project.clip(withID: PreviewFixtures.videoClip.id))
        XCTAssertNotNil(store.project.clip(withID: PreviewFixtures.textClip.id))
        XCTAssertEqual(store.selectedClipID, PreviewFixtures.videoClip.id)
    }

    func testDocumentIsBuiltWithoutTouchingDisk() {
        let store = PreviewFixtures.store()

        let document = PreviewFixtures.document(store: store, library: MediaLibrary())

        XCTAssertFalse(document.hasUnsavedChanges)
    }
}
