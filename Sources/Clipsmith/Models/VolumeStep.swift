import Foundation

struct VolumeStep: Equatable {
    let startInSeconds: TimeInterval
    let durationInSeconds: TimeInterval
    let startVolume: Float
    let endVolume: Float
}
