import Foundation

extension TimeInterval {
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600

    var clockString: String {
        let totalSeconds = isFinite && self > 0 ? Int(rounded()) : 0
        let hours = totalSeconds / Self.secondsPerHour
        let minutes = totalSeconds % Self.secondsPerHour / Self.secondsPerMinute
        let seconds = totalSeconds % Self.secondsPerMinute
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
