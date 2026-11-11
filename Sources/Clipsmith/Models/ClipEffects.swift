import Foundation

struct ColorAdjustments: Codable, Equatable {
    static let brightnessRange = -0.5...0.5
    static let contrastRange = 0.25...2.0
    static let saturationRange = 0.0...2.0
    static let temperatureRange = -1.0...1.0

    var brightness = 0.0
    var contrast = 1.0
    var saturation = 1.0
    var temperature = 0.0

    var isIdentity: Bool { self == ColorAdjustments() }

    func clamped() -> ColorAdjustments {
        func limit(_ value: Double, _ range: ClosedRange<Double>) -> Double {
            min(max(value, range.lowerBound), range.upperBound)
        }
        return ColorAdjustments(
            brightness: limit(brightness, Self.brightnessRange),
            contrast: limit(contrast, Self.contrastRange),
            saturation: limit(saturation, Self.saturationRange),
            temperature: limit(temperature, Self.temperatureRange)
        )
    }
}
