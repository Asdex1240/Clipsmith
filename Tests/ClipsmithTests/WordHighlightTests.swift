import XCTest
@testable import Clipsmith

final class WordHighlightTests: XCTestCase {
    private func line() -> SubtitleLine {
        SubtitleLine(
            text: "hola que tal", startInSeconds: 0, endInSeconds: 3,
            words: [
                TranscribedWord(text: "hola", startInSeconds: 0, durationInSeconds: 1),
                TranscribedWord(text: "que", startInSeconds: 1, durationInSeconds: 1),
                TranscribedWord(text: "tal", startInSeconds: 2, durationInSeconds: 1),
            ])
    }

    func testRangeSelectsTheWordByIndex() {
        let content = "hola que tal"

        XCTAssertEqual(WordHighlight(index: 0).range(in: content), NSRange(location: 0, length: 4))
        XCTAssertEqual(WordHighlight(index: 2).range(in: content), NSRange(location: 9, length: 3))
        XCTAssertNil(WordHighlight(index: 3).range(in: content))
    }

    func testSegmentsCoverTheWholeLineWithoutGaps() {
        let segments = SubtitleSegment.segments(of: line())

        XCTAssertEqual(segments.map(\.wordIndex), [0, 1, 2])
        XCTAssertEqual(segments.map(\.startInSeconds), [0, 1, 2])
        XCTAssertEqual(segments.last?.endInSeconds, 3)
    }

    func testVeryShortWordIsAbsorbedByTheNextSegment() {
        var short = line()
        short = SubtitleLine(
            text: short.text, startInSeconds: 0, endInSeconds: 3,
            words: [
                TranscribedWord(text: "hola", startInSeconds: 0, durationInSeconds: 0.02),
                TranscribedWord(text: "que", startInSeconds: 0.02, durationInSeconds: 1),
                TranscribedWord(text: "tal", startInSeconds: 2, durationInSeconds: 1),
            ])

        let segments = SubtitleSegment.segments(of: short)

        XCTAssertEqual(segments.map(\.wordIndex), [1, 2])
        XCTAssertEqual(segments.first?.startInSeconds, 0)
    }

    func testHighlightedSubtitlesBecomeOneClipPerWord() {
        var project = Project(name: "T")

        let added = project.addSubtitles([line()], highlightColor: .white)

        let clips = project.track(withRole: .text)!.clips
        XCTAssertEqual(added, 1)
        XCTAssertEqual(clips.count, 3)
        XCTAssertEqual(clips.compactMap { $0.textLayer?.wordHighlight?.index }, [0, 1, 2])
        XCTAssertTrue(clips.allSatisfy { $0.textLayer?.content == "hola que tal" })
    }

    func testWithoutHighlightASingleClipIsAdded() {
        var project = Project(name: "T")

        project.addSubtitles([line()])

        XCTAssertEqual(project.track(withRole: .text)!.clips.count, 1)
        XCTAssertNil(project.track(withRole: .text)!.clips[0].textLayer?.wordHighlight)
    }

    func testLinesWithoutWordsFallBackToASingleClip() {
        var project = Project(name: "T")

        project.addSubtitles(
            [SubtitleLine(text: "hola", startInSeconds: 0, endInSeconds: 2)],
            highlightColor: .white)

        XCTAssertEqual(project.track(withRole: .text)!.clips.count, 1)
    }

    func testTextLayerKeepsTheHighlightWhenEncoded() throws {
        var layer = TextLayer(content: "hola que tal")
        layer.wordHighlight = WordHighlight(index: 1)

        let decoded = try JSONDecoder().decode(TextLayer.self, from: JSONEncoder().encode(layer))

        XCTAssertEqual(decoded, layer)
    }

    @MainActor
    func testTimelineLinesKeepTheWordsOnTheTimeline() {
        let clip = TestClips.video(start: 10)

        let lines = SubtitleController.timelineLines(from: [line()], for: clip)

        XCTAssertEqual(lines.first?.words.count, 3)
        XCTAssertEqual(lines.first?.words.first?.startInSeconds, 10 - clip.sourceStartInSeconds)
    }
}
