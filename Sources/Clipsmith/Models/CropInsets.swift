import Foundation

struct CropInsets: Codable, Equatable {
    static let maximumPerAxis = 0.9

    var left = 0.0
    var right = 0.0
    var top = 0.0
    var bottom = 0.0

    var isNone: Bool { self == CropInsets() }

    func clamped() -> CropInsets {
        func fit(_ first: Double, _ second: Double) -> (Double, Double) {
            let a = max(first, 0)
            let b = max(second, 0)
            let total = a + b
            guard total > Self.maximumPerAxis else { return (a, b) }
            let scale = Self.maximumPerAxis / total
            return (a * scale, b * scale)
        }
        let horizontal = fit(left, right)
        let vertical = fit(top, bottom)
        return CropInsets(
            left: horizontal.0, right: horizontal.1, top: vertical.0, bottom: vertical.1)
    }

    func visible(in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + rect.width * left,
            y: rect.minY + rect.height * top,
            width: rect.width * (1 - left - right),
            height: rect.height * (1 - top - bottom)
        )
    }
}
