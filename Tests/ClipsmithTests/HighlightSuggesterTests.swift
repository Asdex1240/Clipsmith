import XCTest
@testable import Clipsmith

final class HighlightSuggesterTests: XCTestCase {
    private let rate = WaveformSpec.peaksPerSecond

    private func peaks(seconds: Int, loud: Range<Int>) -> [Float] {
        (0..<seconds).flatMap { second in
            [Float](repeating: loud.contains(second) ? 0.8 : 0.05, count: Int(rate))
        }
    }

    func testPicksTheLoudestStretch() {
        let data = peaks(seconds: 120, loud: 60..<90)

        let result = HighlightSuggester.suggestions(
            peaks: data, from: 0, to: 120, duration: 30, count: 1)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].lowerBound, 60, accuracy: 2)
        XCTAssertEqual(result[0].upperBound, 90, accuracy: 2)
    }

    func testSuggestionsDoNotOverlapAndAreSorted() {
        let data = peaks(seconds: 200, loud: 20..<200)

        let result = HighlightSuggester.suggestions(
            peaks: data, from: 0, to: 200, duration: 30, count: 4)

        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result, result.sorted { $0.lowerBound < $1.lowerBound })
        for (first, second) in zip(result, result.dropFirst()) {
            XCTAssertLessThanOrEqual(first.upperBound, second.lowerBound + 4)
        }
    }

    func testSilenceYieldsNothing() {
        let data = [Float](repeating: 0, count: Int(rate) * 60)

        XCTAssertTrue(
            HighlightSuggester.suggestions(peaks: data, from: 0, to: 60, duration: 30).isEmpty)
    }

    func testTooShortSourceYieldsNothing() {
        let data = peaks(seconds: 5, loud: 0..<5)

        XCTAssertTrue(HighlightSuggester.suggestions(peaks: data, from: 0, to: 5).isEmpty)
    }

    func testRespectsTheSourceRange() {
        let data = peaks(seconds: 120, loud: 0..<120)

        let result = HighlightSuggester.suggestions(
            peaks: data, from: 40, to: 80, duration: 30, count: 3)

        XCTAssertTrue(result.allSatisfy { $0.lowerBound >= 40 && $0.upperBound <= 80 })
    }

    @MainActor
    func testStoreAddsSuggestionsAsHighlightsInOneUndoStep() {
        let clip = TestClips.video(start: 5)
        let store = ProjectStore(project: Project(name: "T"))
        let data = peaks(seconds: Int(clip.sourceEndInSeconds) + 1, loud: 0..<1000)

        let added = store.suggestHighlights(for: clip, peaks: data, duration: 10, count: 2)

        XCTAssertGreaterThan(added, 0)
        XCTAssertEqual(store.project.highlights.count, added)
        XCTAssertTrue(store.project.highlights.allSatisfy { $0.startInSeconds >= clip.startInSeconds })
        store.undo()
        XCTAssertTrue(store.project.highlights.isEmpty)
    }
}
