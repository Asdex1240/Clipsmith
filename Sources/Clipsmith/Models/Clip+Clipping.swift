import Foundation

extension Clip {
    func clipped(from start: TimeInterval, to end: TimeInterval) -> Clip? {
        guard start < endInSeconds - Self.minimumDurationInSeconds,
            end > startInSeconds + Self.minimumDurationInSeconds
        else { return nil }
        var piece = self
        if start > piece.startInSeconds, let halves = piece.split(at: start) {
            piece = halves.right
        }
        if end < piece.endInSeconds, let halves = piece.split(at: end) {
            piece = halves.left
        }
        return piece
    }
}
