import Foundation

struct SubtitleLine: Equatable {
    let text: String
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval
    var words: [TranscribedWord] = []

    var durationInSeconds: TimeInterval { endInSeconds - startInSeconds }
}
