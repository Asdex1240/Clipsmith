import AVFoundation
import Speech

protocol Transcribing {
    func transcribe(
        url: URL, sourceRange: ClosedRange<TimeInterval>, locale: Locale
    ) async throws -> [TranscribedWord]
}
