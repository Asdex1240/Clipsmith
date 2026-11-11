import Foundation

extension TimeInterval {
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600

    private var wholeSecondsForClock: Int {
        guard isFinite, self > 0 else { return 0 }
        return Int(rounded())
    }

    var clockString: String {
        let totalSeconds = wholeSecondsForClock
        let hours = totalSeconds / Self.secondsPerHour
        let minutes = totalSeconds % Self.secondsPerHour / Self.secondsPerMinute
        let seconds = totalSeconds % Self.secondsPerMinute
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
