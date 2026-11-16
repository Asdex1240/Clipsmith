import Foundation

struct LookEffects: Codable, Equatable {
    static let amountRange = 0.0...1.0

    var grain = 0.0
    var vignette = 0.0
    var sharpness = 0.0
    var lookTable: LookTableReference?

    var isNone: Bool { self == LookEffects() }

    func clamped() -> LookEffects {
        LookEffects(
            grain: Self.limit(grain), vignette: Self.limit(vignette),
            sharpness: Self.limit(sharpness), lookTable: lookTable?.clamped())
    }

    static func limit(_ value: Double) -> Double {
        min(max(value, amountRange.lowerBound), amountRange.upperBound)
    }
}

struct LookTableReference: Codable, Equatable {
    var url: URL
    var intensity = 1.0

    var name: String { url.deletingPathExtension().lastPathComponent }

    func clamped() -> LookTableReference {
        LookTableReference(url: url, intensity: LookEffects.limit(intensity))
    }
}
