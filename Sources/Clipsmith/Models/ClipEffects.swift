import Foundation

/// Color corrections of a visual clip. The defaults leave the picture untouched.
struct ColorAdjustments: Codable, Equatable {
    static let brightnessRange = -0.5...0.5
    static let contrastRange = 0.25...2.0
    static let saturationRange = 0.0...2.0
    static let temperatureRange = -1.0...1.0

    var brightness = 0.0
    var contrast = 1.0
    var saturation = 1.0
    /// Negative cools the picture towards blue, positive warms it towards orange.
    var temperature = 0.0

    var isIdentity: Bool { self == ColorAdjustments() }

    func clamped() -> ColorAdjustments {
        func limit(_ value: Double, _ range: ClosedRange<Double>) -> Double { min(max(value, range.lowerBound), range.upperBound) }
        return ColorAdjustments(
            brightness: limit(brightness, Self.brightnessRange),
            contrast: limit(contrast, Self.contrastRange),
            saturation: limit(saturation, Self.saturationRange),
            temperature: limit(temperature, Self.temperatureRange)
        )
    }
}

enum ColorPreset: CaseIterable {
    case none, blackAndWhite, warm, cool, vivid, faded

    var adjustments: ColorAdjustments {
        switch self {
        case .none: return ColorAdjustments()
        case .blackAndWhite: return ColorAdjustments(contrast: 1.1, saturation: 0)
        case .warm: return ColorAdjustments(saturation: 1.1, temperature: 0.5)
        case .cool: return ColorAdjustments(saturation: 0.95, temperature: -0.5)
        case .vivid: return ColorAdjustments(contrast: 1.15, saturation: 1.5)
        case .faded: return ColorAdjustments(brightness: 0.05, contrast: 0.8, saturation: 0.7)
        }
    }
}

/// How much of each side of a picture is cut away, as a fraction of its width or height.
struct CropInsets: Codable, Equatable {
    /// The two sides of an axis together can never remove more than this.
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
        return CropInsets(left: horizontal.0, right: horizontal.1, top: vertical.0, bottom: vertical.1)
    }

    /// The part of `rect` that stays visible.
    func visible(in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + rect.width * left,
            y: rect.minY + rect.height * top,
            width: rect.width * (1 - left - right),
            height: rect.height * (1 - top - bottom)
        )
    }
}
