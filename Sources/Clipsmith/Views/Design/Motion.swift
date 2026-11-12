import SwiftUI

private struct MotionModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(effectiveAnimation, value: value)
    }

    private var effectiveAnimation: Animation? {
        if reduceMotion { return nil }
        return animation
    }
}

extension View {
    func motion<Value: Equatable>(
        _ animation: Animation = .easeInOut(duration: Design.Motion.quick), value: Value
    ) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}
