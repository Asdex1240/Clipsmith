import CoreGraphics
import Foundation

struct SafeAreaGuides: Equatable {
    static let actionSafeFraction = 0.93
    static let titleSafeFraction = 0.8

    let actionSafe: CGRect
    let titleSafe: CGRect
    let verticalCenter: CGFloat
    let horizontalCenter: CGFloat

    init(in frame: CGRect) {
        actionSafe = Self.inset(frame, fraction: Self.actionSafeFraction)
        titleSafe = Self.inset(frame, fraction: Self.titleSafeFraction)
        verticalCenter = frame.midX
        horizontalCenter = frame.midY
    }

    private static func inset(_ frame: CGRect, fraction: Double) -> CGRect {
        let width = frame.width * fraction
        let height = frame.height * fraction
        return CGRect(
            x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
    }
}
