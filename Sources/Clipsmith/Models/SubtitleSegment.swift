import Foundation

struct SubtitleSegment: Equatable {
    let wordIndex: Int
    let startInSeconds: TimeInterval
    var endInSeconds: TimeInterval

    var durationInSeconds: TimeInterval { endInSeconds - startInSeconds }

    static func segments(of line: SubtitleLine) -> [SubtitleSegment] {
        var result: [SubtitleSegment] = []
        var cursor = line.startInSeconds
        let words = line.words
        for index in words.indices {
            var end = line.endInSeconds
            if index + 1 < words.count {
                end = min(max(words[index + 1].startInSeconds, cursor), line.endInSeconds)
            }
            guard end - cursor >= Clip.minimumDurationInSeconds else { continue }
            result.append(
                SubtitleSegment(wordIndex: index, startInSeconds: cursor, endInSeconds: end))
            cursor = end
        }
        if cursor < line.endInSeconds, !result.isEmpty {
            result[result.count - 1].endInSeconds = line.endInSeconds
        }
        return result
    }
}
