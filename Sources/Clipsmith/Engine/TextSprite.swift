import AVFoundation
import AppKit
import QuartzCore

struct TextSprite {
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval
    let image: CGImage
    let center: CGPoint
    let rotationInRadians: Double
    let animation: TextAnimation
}
