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

    /// Listens to the sound of a clip and adds a text clip for each spoken line, timed to the clip on the timeline.
    func generate(for clipID: Clip.ID, locale: Locale) {
        guard !isWorking, let clip = store.project.clip(withID: clipID), let url = clip.sourceURL,
              clip.mediaKind == .video || clip.mediaKind == .audio else { return }
        state = .working
        task = Task {
            do {
                let words = try await transcriber.transcribe(
                    url: url, sourceRange: clip.sourceStartInSeconds...clip.sourceEndInSeconds, locale: locale
                )
                try Task.checkCancellation()
                let lines = Self.timelineLines(from: SubtitleGrouper.lines(from: words), for: clip)
                guard !lines.isEmpty else { throw SubtitleError.noSpeech }
                let added = store.addSubtitles(lines)
                state = .finished(lineCount: added)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    func dismiss() {
        if !isWorking { state = .idle }
    }

    /// Lines timed in the file's seconds, moved to the timeline: shifted to where the clip sits and scaled by its speed.
    static func timelineLines(from lines: [SubtitleLine], for clip: Clip) -> [SubtitleLine] {
        lines.compactMap { line in
            let start = clip.startInSeconds + (line.startInSeconds - clip.sourceStartInSeconds) / clip.speed
            let end = clip.startInSeconds + (line.endInSeconds - clip.sourceStartInSeconds) / clip.speed
            let clampedStart = max(start, clip.startInSeconds)
            let clampedEnd = min(end, clip.endInSeconds)
            guard clampedEnd - clampedStart >= Clip.minimumDurationInSeconds else { return nil }
            return SubtitleLine(text: line.text, startInSeconds: clampedStart, endInSeconds: clampedEnd)
        }
    }
}
