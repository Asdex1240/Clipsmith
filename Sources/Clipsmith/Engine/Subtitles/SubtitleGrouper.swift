import Foundation

struct TranscribedWord: Equatable {
    let text: String
    let startInSeconds: TimeInterval
    let durationInSeconds: TimeInterval

    var endInSeconds: TimeInterval { startInSeconds + durationInSeconds }
}

struct SubtitleLine: Equatable {
    let text: String
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval

    var durationInSeconds: TimeInterval { endInSeconds - startInSeconds }
}

/// Turns recognized words into subtitle lines that are short enough to read.
enum SubtitleGrouper {
    static let maximumCharacters = 42
    static let maximumDurationInSeconds: TimeInterval = 4
    static let pauseBreakInSeconds: TimeInterval = 0.7
    static let minimumDurationInSeconds: TimeInterval = 0.8
    private static let sentenceEndings: Set<Character> = [".", "?", "!", "…", "。", "？", "！"]

    static func lines(from words: [TranscribedWord]) -> [SubtitleLine] {
        var lines: [SubtitleLine] = []
        var current: [TranscribedWord] = []
        for word in words.sorted(by: { $0.startInSeconds < $1.startInSeconds }) where !trimmed(word).isEmpty {
            if let last = current.last, shouldBreak(before: word, after: last, in: current) {
                lines.append(line(from: current))
                current = []
            }
            current.append(word)
        }
        if !current.isEmpty { lines.append(line(from: current)) }
        return spaced(lines)
    }

    private static func trimmed(_ word: TranscribedWord) -> String {
        word.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldBreak(before word: TranscribedWord, after last: TranscribedWord, in current: [TranscribedWord]) -> Bool {
        if word.startInSeconds - last.endInSeconds > pauseBreakInSeconds { return true }
        if let ending = trimmed(last).last, sentenceEndings.contains(ending) { return true }
        if word.endInSeconds - (current.first?.startInSeconds ?? 0) > maximumDurationInSeconds { return true }
        let length = current.map(trimmed).joined(separator: " ").count + 1 + trimmed(word).count
        return length > maximumCharacters
    }

    private static func line(from words: [TranscribedWord]) -> SubtitleLine {
        SubtitleLine(
            text: words.map(trimmed).joined(separator: " "),
            startInSeconds: words.first?.startInSeconds ?? 0,
            endInSeconds: words.last?.endInSeconds ?? 0
        )
    }

    /// Keeps lines on screen long enough to read without ever overlapping the next one.
    private static func spaced(_ lines: [SubtitleLine]) -> [SubtitleLine] {
        lines.enumerated().map { index, line in
            let latestEnd = index + 1 < lines.count ? lines[index + 1].startInSeconds : .infinity
            let end = min(max(line.endInSeconds, line.startInSeconds + minimumDurationInSeconds), latestEnd)
            return SubtitleLine(text: line.text, startInSeconds: line.startInSeconds, endInSeconds: max(end, line.startInSeconds))
        }
    }
}
