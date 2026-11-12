import CoreGraphics
import Foundation

struct Filmstrip {
    static let secondsPerFrame: TimeInterval = 2
    static let maximumFrameCount = 120

    let frames: [CGImage]
    let durationInSeconds: TimeInterval

    static func frameTimes(forDuration duration: TimeInterval) -> [TimeInterval] {
        guard duration > 0 else { return [] }
        let wanted = Int((duration / secondsPerFrame).rounded(.up))
        let count = min(max(wanted, 1), maximumFrameCount)
        let step = duration / Double(count)
        return (0..<count).map { (Double($0) + 0.5) * step }
    }

    func frame(atSourceTime time: TimeInterval) -> CGImage? {
        guard !frames.isEmpty, durationInSeconds > 0 else { return nil }
        let index = Int(time / durationInSeconds * Double(frames.count))
        return frames[min(max(index, 0), frames.count - 1)]
    }
}
