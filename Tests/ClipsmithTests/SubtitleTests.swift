import XCTest
@testable import Clipsmith

@MainActor
final class SubtitleTests: XCTestCase {
    private func word(_ text: String, _ start: TimeInterval, _ duration: TimeInterval = 0.3) -> TranscribedWord {
        TranscribedWord(text: text, startInSeconds: start, durationInSeconds: duration)
    }

    // MARK: Grouping

    func testWordsCloseTogetherShareALine() {
        let lines = SubtitleGrouper.lines(from: [word("Hello", 0), word("there", 0.4), word("friend", 0.8)])

        XCTAssertEqual(lines.map(\.text), ["Hello there friend"])
        XCTAssertEqual(lines[0].startInSeconds, 0)
        XCTAssertEqual(lines[0].endInSeconds, 1.1, accuracy: 1e-9)
    }

    func testALongPauseStartsANewLine() {
        let lines = SubtitleGrouper.lines(from: [word("One", 0), word("two", 0.4), word("three", 3)])

        XCTAssertEqual(lines.map(\.text), ["One two", "three"])
    }

    func testSentenceEndsStartANewLine() {
        let lines = SubtitleGrouper.lines(from: [word("Stop.", 0), word("Go", 0.4)])

        XCTAssertEqual(lines.map(\.text), ["Stop.", "Go"])
    }

    func testLinesAreKeptShort() {
        let words = (0..<30).map { word("palabra", Double($0) * 0.35, 0.3) }

        let lines = SubtitleGrouper.lines(from: words)

        XCTAssertGreaterThan(lines.count, 1)
        XCTAssertTrue(lines.allSatisfy { $0.text.count <= SubtitleGrouper.maximumCharacters })
        XCTAssertTrue(lines.allSatisfy { $0.durationInSeconds <= SubtitleGrouper.maximumDurationInSeconds + 1e-9 })
    }

    func testShortLinesStayLongEnoughToReadWithoutOverlapping() {
        let lines = SubtitleGrouper.lines(from: [word("Hi", 0, 0.2), word("Bye", 0.5, 0.2)])

        XCTAssertEqual(lines.count, 1)
        let spaced = SubtitleGrouper.lines(from: [word("Hi.", 0, 0.2), word("Bye", 0.5, 0.2)])
        XCTAssertEqual(spaced.map(\.text), ["Hi.", "Bye"])
        XCTAssertEqual(spaced[0].endInSeconds, 0.5, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(spaced[1].durationInSeconds, SubtitleGrouper.minimumDurationInSeconds)
    }

    func testEmptyWordsAndUnorderedInputAreHandled() {
        XCTAssertTrue(SubtitleGrouper.lines(from: []).isEmpty)
        XCTAssertTrue(SubtitleGrouper.lines(from: [word("  ", 0)]).isEmpty)
        XCTAssertEqual(SubtitleGrouper.lines(from: [word("two", 0.4), word("one", 0)]).map(\.text), ["one two"])
    }

    // MARK: Timeline mapping

    func testLinesAreMovedToWhereTheClipSitsOnTheTimeline() {
        let clip = Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"), mediaKind: .video, startInSeconds: 10,
            sourceStartInSeconds: 5, sourceEndInSeconds: 15, sourceDurationInSeconds: 60
        )

        let lines = SubtitleController.timelineLines(
            from: [SubtitleLine(text: "Hi", startInSeconds: 6, endInSeconds: 8)], for: clip
        )

        XCTAssertEqual(lines, [SubtitleLine(text: "Hi", startInSeconds: 11, endInSeconds: 13)])
    }

    func testLinesFollowTheClipSpeedAndAreCutToTheClip() {
        var clip = Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"), mediaKind: .video, startInSeconds: 0,
            sourceStartInSeconds: 0, sourceEndInSeconds: 10, sourceDurationInSeconds: 60
        )
        clip.speed = 2

        let lines = SubtitleController.timelineLines(
            from: [
                SubtitleLine(text: "inside", startInSeconds: 2, endInSeconds: 4),
                SubtitleLine(text: "straddling", startInSeconds: 4, endInSeconds: 8),
                SubtitleLine(text: "outside", startInSeconds: 9.9, endInSeconds: 12),
            ],
            for: clip
        )

        XCTAssertEqual(lines.map(\.text), ["inside", "straddling"])
        XCTAssertEqual(lines[0].startInSeconds, 1)
        XCTAssertEqual(lines[1].endInSeconds, 4)
        XCTAssertLessThanOrEqual(lines[1].endInSeconds, clip.endInSeconds)
    }

    // MARK: Controller

    private struct StubTranscriber: Transcribing {
        var words: [TranscribedWord] = []
        var error: Error?
        var onCall: (@Sendable (ClosedRange<TimeInterval>, Locale) -> Void)?

        func transcribe(url: URL, sourceRange: ClosedRange<TimeInterval>, locale: Locale) async throws -> [TranscribedWord] {
            onCall?(sourceRange, locale)
            if let error { throw error }
            return words
        }
    }

    private func makeStore() -> (ProjectStore, Clip) {
        let store = ProjectStore(project: Project(name: "T"))
        store.addMedia(TestClips.mediaItem(duration: 10), toTrack: store.project.track(withRole: .main)!.id, at: 0)
        return (store, store.selectedClip!)
    }

    private func settle(_ controller: SubtitleController) async {
        for _ in 0..<200 where controller.isWorking {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testGeneratingAddsTextClipsToTheTextTrack() async throws {
        let (store, clip) = makeStore()
        let words = [
            TranscribedWord(text: "Hola", startInSeconds: 1, durationInSeconds: 0.4),
            TranscribedWord(text: "mundo.", startInSeconds: 1.5, durationInSeconds: 0.5),
            TranscribedWord(text: "Adiós", startInSeconds: 5, durationInSeconds: 0.5),
        ]
        let controller = SubtitleController(store: store, transcriber: StubTranscriber(words: words))

        controller.generate(for: clip.id, locale: Locale(identifier: "es_ES"))
        await settle(controller)

        XCTAssertEqual(controller.state, .finished(lineCount: 2))
        let texts = try XCTUnwrap(store.project.track(withRole: .text)).clips
        XCTAssertEqual(texts.compactMap(\.textLayer?.content), ["Hola mundo.", "Adiós"])
        XCTAssertEqual(texts[0].startInSeconds, 1, accuracy: 1e-9)
        XCTAssertEqual(texts[0].textLayer?.positionY, TextLayer.subtitlePositionY)
    }

    func testTheClipRangeAndChosenLanguageReachTheTranscriber() async {
        let (store, clip) = makeStore()
        nonisolated(unsafe) var seen: (ClosedRange<TimeInterval>, String)?
        let transcriber = StubTranscriber(words: [], error: SubtitleError.noSpeech) { range, locale in
            seen = (range, locale.identifier)
        }
        let controller = SubtitleController(store: store, transcriber: transcriber)

        controller.generate(for: clip.id, locale: Locale(identifier: "fr_FR"))
        await settle(controller)

        XCTAssertEqual(seen?.0, 0...10)
        XCTAssertEqual(seen?.1, "fr_FR")
    }

    func testFailuresAreReportedAndNothingIsAdded() async {
        let (store, clip) = makeStore()
        let controller = SubtitleController(store: store, transcriber: StubTranscriber(error: SubtitleError.notAuthorized))

        controller.generate(for: clip.id, locale: .current)
        await settle(controller)

        XCTAssertEqual(controller.state, .failed(SubtitleError.notAuthorized.localizedDescription))
        XCTAssertTrue(store.project.track(withRole: .text)!.clips.isEmpty)
    }

    func testNoSpeechIsReportedInsteadOfAddingNothingSilently() async {
        let (store, clip) = makeStore()
        let controller = SubtitleController(store: store, transcriber: StubTranscriber(words: []))

        controller.generate(for: clip.id, locale: .current)
        await settle(controller)

        XCTAssertEqual(controller.state, .failed(SubtitleError.noSpeech.localizedDescription))
    }

    func testAllSubtitlesAreOneUndoStep() async {
        let (store, clip) = makeStore()
        let words = [word("Uno", 1), word("dos.", 1.4), word("tres", 5)]
        let controller = SubtitleController(store: store, transcriber: StubTranscriber(words: words))

        controller.generate(for: clip.id, locale: .current)
        await settle(controller)
        store.undo()

        XCTAssertTrue(store.project.track(withRole: .text)!.clips.isEmpty)
    }

    func testTextClipsAreNotTranscribed() {
        let store = ProjectStore(project: Project(name: "T"))
        store.addTextAtPlayhead()
        let controller = SubtitleController(store: store, transcriber: StubTranscriber())

        controller.generate(for: store.selectedClip!.id, locale: .current)

        XCTAssertEqual(controller.state, .idle)
    }

    // MARK: Speech

    func testSpeechRecognitionRefusesToRunOutsideThePackagedApp() async {
        do {
            _ = try await SpeechTranscriber().transcribe(
                url: URL(fileURLWithPath: "/tmp/none.mp4"), sourceRange: 0...1, locale: Locale(identifier: "en_US")
            )
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? SubtitleError, .requiresPackagedApp)
        }
    }

    func testDefaultLanguageFollowsTheSystemWhenSupported() {
        let locales = ["en_US", "es_ES", "es_MX", "fr_FR"].map(Locale.init(identifier:))

        XCTAssertEqual(SubtitleInspector.defaultIdentifier(in: locales, system: Locale(identifier: "es_MX")), "es_MX")
        XCTAssertEqual(SubtitleInspector.defaultIdentifier(in: locales, system: Locale(identifier: "es_AR")), "es_ES")
        XCTAssertEqual(SubtitleInspector.defaultIdentifier(in: locales, system: Locale(identifier: "ja_JP")), "en_US")
    }
}
