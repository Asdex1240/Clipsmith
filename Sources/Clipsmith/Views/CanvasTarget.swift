import CoreGraphics
import Foundation

struct CanvasTarget: Identifiable {
    let id: Clip.ID
    let isText: Bool
    let center: CGPoint
    let size: CGSize
    let rotationInDegrees: Double

    var bounds: CGRect {
        let radians = rotationInDegrees * .pi / 180
        let cosine = abs(cos(radians)), sine = abs(sin(radians))
        let width = size.width * cosine + size.height * sine
        let height = size.width * sine + size.height * cosine
        return CGRect(
            x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}
