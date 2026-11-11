import Foundation

struct PlannedTransition: Equatable {
    let outgoingClipID: Clip.ID
    let incomingClipID: Clip.ID
    let kind: TransitionKind
    let windowStart: TimeInterval
    let windowEnd: TimeInterval
    var easing = Easing.linear

    func progress(at time: TimeInterval) -> Double {
        guard windowEnd > windowStart else { return 1 }
        return easing.apply((time - windowStart) / (windowEnd - windowStart))
    }
}

struct PlannedSegment: Equatable {
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval
    let clipIDsTopFirst: [Clip.ID]
    var transitions: [PlannedTransition] = []
}

enum CompositionPlanner {
    private static let toleranceInSeconds: TimeInterval = 1e-6
    private static let minimumTransitionInSeconds: TimeInterval = 0.05

    static func segments(for project: Project) -> [PlannedSegment] {
        let videoClips = project.videoTracksTopFirst.flatMap(\.clips)
        let transitions = plannedTransitions(in: project)
        let boundaries = boundaries(
            of: videoClips,
            extra: transitions.flatMap { [$0.windowStart, $0.windowEnd] },
            projectDuration: project.durationInSeconds
        )
        return zip(boundaries, boundaries.dropFirst()).map { start, end in
            PlannedSegment(
                startInSeconds: start,
                endInSeconds: end,
                clipIDsTopFirst: videoClips.filter { covers($0, from: start, to: end) }.map(\.id),
                transitions: transitions.filter {
                    $0.windowStart <= start + toleranceInSeconds
                        && $0.windowEnd >= end - toleranceInSeconds
                }
            )
        }
    }

    static func clamp(
        _ segments: [PlannedSegment], toDuration duration: TimeInterval
    ) -> [PlannedSegment] {
        segments
            .filter { $0.startInSeconds < duration - toleranceInSeconds }
            .map {
                PlannedSegment(
                    startInSeconds: $0.startInSeconds,
                    endInSeconds: min($0.endInSeconds, duration),
                    clipIDsTopFirst: $0.clipIDsTopFirst,
                    transitions: $0.transitions
                )
            }
    }

    private static func plannedTransitions(in project: Project) -> [PlannedTransition] {
        project.videoTracksTopFirst.flatMap { track -> [PlannedTransition] in
            track.clips.compactMap { clip in
                guard let transition = clip.transition,
                    let outgoing = project.clipBeforeAndTouching(clip.id),
                    outgoing.mediaKind == .video || outgoing.mediaKind == .image
                else { return nil }
                let duration = min(transition.durationInSeconds, clip.durationInSeconds)
                guard duration >= minimumTransitionInSeconds else { return nil }
                return PlannedTransition(
                    outgoingClipID: outgoing.id,
                    incomingClipID: clip.id,
                    kind: transition.kind,
                    windowStart: clip.startInSeconds,
                    windowEnd: clip.startInSeconds + duration,
                    easing: transition.easing
                )
            }
        }
    }

    private static func boundaries(
        of clips: [Clip], extra: [TimeInterval], projectDuration: TimeInterval
    ) -> [TimeInterval] {
        guard projectDuration > 0 else { return [] }
        let all =
            ([0, projectDuration] + extra + clips.flatMap { [$0.startInSeconds, $0.endInSeconds] })
            .filter { $0 <= projectDuration + toleranceInSeconds }
            .sorted()
        return all.reduce(into: [TimeInterval]()) { unique, value in
            if let last = unique.last, value - last <= toleranceInSeconds { return }
            unique.append(value)
        }
    }

    private static func covers(_ clip: Clip, from start: TimeInterval, to end: TimeInterval) -> Bool
    {
        clip.startInSeconds <= start + toleranceInSeconds
            && clip.endInSeconds >= end - toleranceInSeconds
    }
}
