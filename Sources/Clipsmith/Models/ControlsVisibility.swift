import Foundation

struct ControlsVisibility: Equatable {
    static let hideDelayInSeconds: TimeInterval = 2.5

    var isPlaying: Bool
    var pointerIsIdle: Bool
    var pointerIsOverControls = false

    var isVisible: Bool {
        !isPlaying || !pointerIsIdle || pointerIsOverControls
    }
}
