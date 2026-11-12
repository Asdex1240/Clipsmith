import Foundation

extension ProjectStore {
    func clipForDisplay(_ clip: Clip) -> Clip {
        guard clip.isAnimated else { return clip }
        return clip.presented(atTimelineTime: playheadInSeconds)
    }
}
