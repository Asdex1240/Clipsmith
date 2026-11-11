import AVFoundation
import Speech

enum SubtitleError: Error, LocalizedError, Equatable {
    case requiresPackagedApp
    case notAuthorized
    case languageUnavailable
    case noAudio
    case noSpeech
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .requiresPackagedApp: return localized("error.subtitles.packaged")
        case .notAuthorized: return localized("error.subtitles.denied")
        case .languageUnavailable: return localized("error.subtitles.language")
        case .noAudio: return localized("error.subtitles.noAudio")
        case .noSpeech: return localized("error.subtitles.noSpeech")
        case .failed(let reason): return String(format: localized("error.subtitles.failed"), reason)
        }
    }
}

protocol Transcribing {
    func transcribe(url: URL, sourceRange: ClosedRange<TimeInterval>, locale: Locale) async throws -> [TranscribedWord]
}

struct SpeechTranscriber: Transcribing {
    private static let serverChunkInSeconds: TimeInterval = 55
    private static let noSpeechErrorCode = 1110

    static var canAskForPermission: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil
    }

    static var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales().sorted {
            ($0.localizedString(forIdentifier: $0.identifier) ?? $0.identifier)
                < ($1.localizedString(forIdentifier: $1.identifier) ?? $1.identifier)
        }
    }

    func transcribe(url: URL, sourceRange: ClosedRange<TimeInterval>, locale: Locale) async throws -> [TranscribedWord] {
        guard Self.canAskForPermission else { throw SubtitleError.requiresPackagedApp }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SubtitleError.languageUnavailable
        }
        try await authorize()
        guard try await !AVURLAsset(url: url).loadTracks(withMediaType: .audio).isEmpty else { throw SubtitleError.noAudio }
        let onDevice = recognizer.supportsOnDeviceRecognition
        var chunk = Self.serverChunkInSeconds
        if onDevice { chunk = sourceRange.upperBound - sourceRange.lowerBound }
        var words: [TranscribedWord] = []
        var start = sourceRange.lowerBound
        while start < sourceRange.upperBound {
            try Task.checkCancellation()
            let end = min(start + max(chunk, 1), sourceRange.upperBound)
            let audio = try await extractAudio(of: url, from: start, to: end)
            defer { try? FileManager.default.removeItem(at: audio) }
            let recognized = try await recognize(audio, with: recognizer, onDevice: onDevice)
            words += recognized.map {
                TranscribedWord(text: $0.text, startInSeconds: $0.startInSeconds + start, durationInSeconds: $0.durationInSeconds)
            }
            start = end
        }
        return words
    }

    private func authorize() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw SubtitleError.notAuthorized }
    }

    private func extractAudio(of url: URL, from start: TimeInterval, to end: TimeInterval) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SubtitleError.noAudio
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("subtitles-\(UUID().uuidString).m4a")
        session.outputURL = destination
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(start: start.cmTime, end: end.cmTime)
        nonisolated(unsafe) let exporting = session
        await withCheckedContinuation { continuation in
            exporting.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else {
            throw SubtitleError.failed(session.error?.localizedDescription ?? "")
        }
        return destination
    }

    private func recognize(_ audio: URL, with recognizer: SFSpeechRecognizer, onDevice: Bool) async throws -> [TranscribedWord] {
        let request = SFSpeechURLRecognitionRequest(url: audio)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = onDevice
        let holder = TaskHolder()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let once = ResumeOnce(continuation)
                holder.task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        once.resume(returning: result.bestTranscription.segments.map {
                            TranscribedWord(text: $0.substring, startInSeconds: $0.timestamp, durationInSeconds: $0.duration)
                        })
                    } else if let error {
                        let code = (error as NSError).code
                        if code == Self.noSpeechErrorCode {
                            once.resume(returning: [])
                        } else {
                            once.resume(throwing: SubtitleError.failed(error.localizedDescription))
                        }
                    }
                }
            }
        } onCancel: {
            holder.task?.cancel()
        }
    }
}

private final class TaskHolder: @unchecked Sendable {
    var task: SFSpeechRecognitionTask?
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[TranscribedWord], Error>?

    init(_ continuation: CheckedContinuation<[TranscribedWord], Error>) {
        self.continuation = continuation
    }

    func resume(returning value: [TranscribedWord]) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<[TranscribedWord], Error>? {
        lock.lock()
        defer { lock.unlock() }
        defer { continuation = nil }
        return continuation
    }
}
