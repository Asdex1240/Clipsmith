import XCTest
@testable import Clipsmith

private struct StubLocator: FaceLocating {
    var sample: FaceSample?

    func faceSample(in url: URL, at times: [TimeInterval]) async -> FaceSample? { sample }
}

final class FaceFramingTests: XCTestCase {
    private let landscape = 16.0 / 9
    private let portrait = 9.0 / 16

    func testCenteredFaceNeedsNoShift() throws {
        let offset = FaceFraming.offsetX(
            faceCenters: [0.5], sourceAspect: landscape, canvasAspect: portrait)

        XCTAssertEqual(try XCTUnwrap(offset), 0, accuracy: 1e-9)
    }

    func testFaceOnTheRightMovesTheImageLeft() throws {
        let offset = FaceFraming.offsetX(
            faceCenters: [0.7], sourceAspect: landscape, canvasAspect: portrait)

        XCTAssertLessThan(try XCTUnwrap(offset), 0)
    }

    func testFaceOnTheLeftMovesTheImageRight() throws {
        let offset = FaceFraming.offsetX(
            faceCenters: [0.3], sourceAspect: landscape, canvasAspect: portrait)

        XCTAssertGreaterThan(try XCTUnwrap(offset), 0)
    }

    func testOffsetNeverExposesEmptyBars() throws {
        let ratio = landscape / portrait

        let offset = FaceFraming.offsetX(
            faceCenters: [0.99], sourceAspect: landscape, canvasAspect: portrait)

        XCTAssertGreaterThanOrEqual(try XCTUnwrap(offset), -(ratio - 1) / 2 - 1e-9)
    }

    func testUsesTheMedianSoOutliersDoNotMatter() throws {
        let offset = FaceFraming.offsetX(
            faceCenters: [0.5, 0.5, 0.5, 0.95], sourceAspect: landscape, canvasAspect: portrait)

        XCTAssertEqual(try XCTUnwrap(offset), 0, accuracy: 1e-9)
    }

    func testNoFacesOrNarrowSourceGivesNoShift() {
        XCTAssertNil(
            FaceFraming.offsetX(faceCenters: [], sourceAspect: landscape, canvasAspect: portrait))
        XCTAssertEqual(
            FaceFraming.offsetX(faceCenters: [0.8], sourceAspect: 0.5, canvasAspect: portrait), 0)
    }

    @MainActor
    func testStoreAppliesTheFramingToTheHighlight() async {
        let clip = TestClips.video(start: 0)
        var project = Project(name: "T")
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        let store = ProjectStore(project: project)
        let id = store.addHighlight(from: 1, to: 6)!
        let locator = StubLocator(sample: FaceSample(centers: [0.8], sourceAspect: landscape))

        let framed = await store.autoFrameHighlight(id, using: locator)

        XCTAssertTrue(framed)
        XCTAssertLessThan(store.project.highlight(withID: id)!.framingOffsetX, 0)
    }

    @MainActor
    func testStoreLeavesFramingAloneWithoutFaces() async {
        let clip = TestClips.video(start: 0)
        var project = Project(name: "T")
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        let store = ProjectStore(project: project)
        let id = store.addHighlight(from: 1, to: 6)!
        let locator = StubLocator(sample: FaceSample(centers: [], sourceAspect: landscape))

        let framed = await store.autoFrameHighlight(id, using: locator)

        XCTAssertFalse(framed)
        XCTAssertEqual(store.project.highlight(withID: id)!.framingOffsetX, 0)
    }
}
