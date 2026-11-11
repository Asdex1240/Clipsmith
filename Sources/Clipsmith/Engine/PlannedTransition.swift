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
