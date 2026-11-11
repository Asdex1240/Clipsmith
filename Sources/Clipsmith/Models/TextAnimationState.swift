import Foundation

struct TextAnimationState: Equatable {
    var opacity = 1.0
    var offsetY = 0.0
    var scale = 1.0

    static let identity = TextAnimationState()
}
