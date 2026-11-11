import Foundation

struct VisualState: Codable, Equatable {
    var offsetX = 0.0
    var offsetY = 0.0
    var scale = 1.0
    var rotationInDegrees = 0.0
    var opacity = 1.0

    func interpolated(to other: VisualState, fraction: Double) -> VisualState {
        func mix(_ from: Double, _ to: Double) -> Double { from + (to - from) * fraction }
        return VisualState(
            offsetX: mix(offsetX, other.offsetX),
            offsetY: mix(offsetY, other.offsetY),
            scale: mix(scale, other.scale),
            rotationInDegrees: mix(rotationInDegrees, other.rotationInDegrees),
            opacity: mix(opacity, other.opacity)
        )
    }
}
