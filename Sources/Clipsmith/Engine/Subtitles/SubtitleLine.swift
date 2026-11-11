import Foundation

struct SubtitleLine: Equatable {
    let text: String
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval

    var durationInSeconds: TimeInterval { endInSeconds - startInSeconds }
}
