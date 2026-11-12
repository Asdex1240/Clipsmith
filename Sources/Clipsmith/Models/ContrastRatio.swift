import Foundation

enum ContrastRatio {
    static let minimumForText = 4.5
    static let minimumForGraphics = 3.0

    private static let linearThreshold = 0.03928
    private static let linearDivisor = 12.92
    private static let gammaOffset = 0.055
    private static let gammaScale = 1.055
    private static let gamma = 2.4
    private static let flare = 0.05

    static func relativeLuminance(of color: RGBAColor) -> Double {
        0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    static func ratio(_ first: RGBAColor, _ second: RGBAColor) -> Double {
        let lighter = max(relativeLuminance(of: first), relativeLuminance(of: second))
        let darker = min(relativeLuminance(of: first), relativeLuminance(of: second))
        return (lighter + flare) / (darker + flare)
    }

    private static func linear(_ component: Double) -> Double {
        guard component > linearThreshold else { return component / linearDivisor }
        return pow((component + gammaOffset) / gammaScale, gamma)
    }
}

extension RGBAColor {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}
