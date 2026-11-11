import Foundation
import Observation

@MainActor
@Observable
final class SubtitleController {
    enum State: Equatable {
        case idle
        case working
        case finished(lineCount: Int)
        case failed(String)
    }

    private(set) var state: State = .idle
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let transcriber: Transcribing
    @ObservationIgnored private var task: Task<Void, Never>?

    init(store: ProjectStore, transcriber: Transcribing = SpeechTranscriber()) {
        self.store = store
        self.transcriber = transcriber
    }

    var isWorking: Bool { state == .working }

    func generate(
        for clipID: Clip.ID, locale: Locale, style: TextStylePreset = .classic,
        animation: TextAnimation = TextAnimation(),
        wordHighlighting: SpokenWordHighlighting = .off
    ) {
        guard !isWorking, let clip = store.project.clip(withID: clipID), let url = clip.sourceURL,
            clip.mediaKind == .video || clip.mediaKind == .audio
        else { return }
        state = .working
        task = Task {
            do {
                let lines = try await subtitleLines(for: clip, from: url, locale: locale)
                let added = store.addSubtitles(
                    lines, style: style, animation: animation,
                    highlightColor: spokenWordColor(for: style, wordHighlighting))
                state = .finished(lineCount: added)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func subtitleLines(
        for clip: Clip, from url: URL, locale: Locale
    ) async throws -> [SubtitleLine] {
        let words = try await transcriber.transcribe(
            url: url, sourceRange: clip.sourceStartInSeconds...clip.sourceEndInSeconds,
            locale: locale
        )
        try Task.checkCancellation()
        let lines = Self.timelineLines(from: SubtitleGrouper.lines(from: words), for: clip)
        guard !lines.isEmpty else { throw SubtitleError.noSpeech }
        return lines
    }

    func cancel() {
        task?.cancel()
    }

    func dismiss() {
        if !isWorking { state = .idle }
    }

    private func spokenWordColor(
        for style: TextStylePreset, _ wordHighlighting: SpokenWordHighlighting
    ) -> RGBAColor? {
        guard wordHighlighting == .on else { return nil }
        return Self.highlightColor(for: style)
    }

    static func highlightColor(for style: TextStylePreset) -> RGBAColor {
        if style == .highlight { return .white }
        return WordHighlight.defaultColor
    }

    static func timelineLines(from lines: [SubtitleLine], for clip: Clip) -> [SubtitleLine] {
        func timelineTime(_ source: TimeInterval) -> TimeInterval {
            clip.startInSeconds + (source - clip.sourceStartInSeconds) / clip.speed
        }
        return lines.compactMap { line in
            let start = timelineTime(line.startInSeconds)
            let end = timelineTime(line.endInSeconds)
            let clampedStart = max(start, clip.startInSeconds)
            let clampedEnd = min(end, clip.endInSeconds)
            guard clampedEnd - clampedStart >= Clip.minimumDurationInSeconds else { return nil }
            let words = line.words.map {
                TranscribedWord(
                    text: $0.text, startInSeconds: timelineTime($0.startInSeconds),
                    durationInSeconds: $0.durationInSeconds / clip.speed)
            }
            return SubtitleLine(
                text: line.text, startInSeconds: clampedStart, endInSeconds: clampedEnd,
                words: words)
        }
    }
}
