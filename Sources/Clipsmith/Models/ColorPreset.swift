import Foundation

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
