import Foundation

enum TextStylePreset: String, CaseIterable {
    case classic
    case outlined
    case boxed
    case highlight

    func apply(to layer: inout TextLayer) {
        layer.color = .white
        layer.strokeWidth = 0
        layer.strokeColor = .black
        layer.backgroundColor = nil
        layer.hasShadow = true
        switch self {
        case .classic:
            break
        case .outlined:
            layer.strokeWidth = TextLayer.outlinedStrokeWidth
            layer.hasShadow = false
        case .boxed:
            layer.backgroundColor = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.65)
            layer.hasShadow = false
        case .highlight:
            layer.color = RGBAColor(red: 1, green: 0.85, blue: 0.1)
            layer.strokeWidth = TextLayer.outlinedStrokeWidth
            layer.hasShadow = false
        }
    }
}
