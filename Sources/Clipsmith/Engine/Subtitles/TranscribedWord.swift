import Foundation

struct TranscribedWord: Equatable {
    let text: String
    let startInSeconds: TimeInterval
    let durationInSeconds: TimeInterval

    var endInSeconds: TimeInterval { startInSeconds + durationInSeconds }
}
