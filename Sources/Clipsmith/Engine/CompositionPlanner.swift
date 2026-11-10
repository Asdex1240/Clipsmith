import Foundation

struct PlannedSegment: Equatable {
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval
    let clipIDsTopFirst: [Clip.ID]
}

enum CompositionPlanner {
    private static let videoRolesTopFirst: [Track.Role] = [.broll, .main]
    private static let toleranceInSeconds: TimeInterval = 1e-6

    static func segments(for project: Project) -> [PlannedSegment] {
        let videoClips = videoRolesTopFirst.flatMap { project.track(withRole: $0)?.clips ?? [] }
        let boundaries = boundaries(of: videoClips, projectDuration: project.durationInSeconds)
        return zip(boundaries, boundaries.dropFirst()).map { start, end in
            PlannedSegment(
                startInSeconds: start,
                endInSeconds: end,
                clipIDsTopFirst: videoClips.filter { covers($0, from: start, to: end) }.map(\.id)
            )
        }
    }

    static func clamp(_ segments: [PlannedSegment], toDuration duration: TimeInterval) -> [PlannedSegment] {
        segments
            .filter { $0.startInSeconds < duration - toleranceInSeconds }
            .map {
                PlannedSegment(
                    startInSeconds: $0.startInSeconds,
                    endInSeconds: min($0.endInSeconds, duration),
                    clipIDsTopFirst: $0.clipIDsTopFirst
                )
            }
    }

    private static func boundaries(of clips: [Clip], projectDuration: TimeInterval) -> [TimeInterval] {
        guard projectDuration > 0 else { return [] }
        let all = ([0, projectDuration] + clips.flatMap { [$0.startInSeconds, $0.endInSeconds] }).sorted()
        return all.reduce(into: [TimeInterval]()) { unique, value in
            if let last = unique.last, value - last <= toleranceInSeconds { return }
            unique.append(value)
        }
    }

    private static func covers(_ clip: Clip, from start: TimeInterval, to end: TimeInterval) -> Bool {
        clip.startInSeconds <= start + toleranceInSeconds && clip.endInSeconds >= end - toleranceInSeconds
    }
}
