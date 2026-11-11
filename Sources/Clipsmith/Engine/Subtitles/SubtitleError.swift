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
