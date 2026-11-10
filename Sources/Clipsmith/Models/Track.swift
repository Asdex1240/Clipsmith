import Foundation

struct Track: Codable, Identifiable, Equatable {
    enum Role: String, Codable {
        case broll, main, audio, text

        func accepts(_ kind: MediaKind) -> Bool {
            switch self {
            case .broll, .main: return kind == .video || kind == .image
            case .audio: return kind == .audio
            case .text: return kind == .text
            }
        }

        var playsAudio: Bool {
            self == .main || self == .audio
        }

        static func preferred(for kind: MediaKind) -> Role {
            switch kind {
            case .audio: return .audio
            case .text: return .text
            case .video, .image: return .main
            }
        }
    }

    static let overlapToleranceInSeconds: TimeInterval = 1e-9

    var id = UUID()
    var role: Role
    /// A name chosen by the user; without one the track is called after its role.
    var name: String?
    var clips: [Clip] = []

    var endInSeconds: TimeInterval {
        clips.map(\.endInSeconds).max() ?? 0
    }

    func previousEnd(before clip: Clip) -> TimeInterval {
        clips
            .filter { $0.id != clip.id && $0.endInSeconds <= clip.startInSeconds + Self.overlapToleranceInSeconds }
            .map(\.endInSeconds)
            .max() ?? 0
    }

    func nextStart(after clip: Clip) -> TimeInterval {
        clips
            .filter { $0.id != clip.id && $0.startInSeconds >= clip.endInSeconds - Self.overlapToleranceInSeconds }
            .map(\.startInSeconds)
            .min() ?? .infinity
    }

    func nearestFreeStart(
        forDuration duration: TimeInterval,
        near proposed: TimeInterval,
        excluding excludedID: Clip.ID?
    ) -> TimeInterval {
        let others = clips.filter { $0.id != excludedID }
        let wanted = max(0, proposed)
        guard isOccupied(start: wanted, duration: duration, by: others) else { return wanted }
        let candidates = [0] + others.map(\.endInSeconds) + others.map { $0.startInSeconds - duration }
        let free = candidates.filter { $0 >= 0 && !isOccupied(start: $0, duration: duration, by: others) }
        return free.min { abs($0 - wanted) < abs($1 - wanted) } ?? wanted
    }

    private func isOccupied(start: TimeInterval, duration: TimeInterval, by others: [Clip]) -> Bool {
        others.contains { other in
            start < other.endInSeconds - Self.overlapToleranceInSeconds
                && start + duration > other.startInSeconds + Self.overlapToleranceInSeconds
        }
    }
}
