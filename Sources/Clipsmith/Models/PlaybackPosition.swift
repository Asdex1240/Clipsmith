import Foundation

struct PlaybackPosition: Equatable {
    let currentInSeconds: TimeInterval
    let durationInSeconds: TimeInterval

    var fraction: Double {
        guard durationInSeconds > 0 else { return 0 }
        return min(max(currentInSeconds / durationInSeconds, 0), 1)
    }

    var text: String {
        "\(currentInSeconds.clockString) / \(durationInSeconds.clockString)"
    }

    var isPlayable: Bool {
        durationInSeconds > 0
    }

    func time(atFraction fraction: Double) -> TimeInterval {
        min(max(fraction, 0), 1) * durationInSeconds
    }

    func time(offsetBy seconds: TimeInterval) -> TimeInterval {
        min(max(currentInSeconds + seconds, 0), durationInSeconds)
    }
}
