import Foundation

struct PlannedSegment: Equatable {
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval
    let clipIDsTopFirst: [Clip.ID]
    var transitions: [PlannedTransition] = []
}
