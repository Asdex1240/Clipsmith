import Foundation

struct TextLayer: Codable, Equatable {
    static let referenceShortSide = 1080.0
    static let defaultFontName = "HelveticaNeue-Bold"
    static let defaultFontSize = 72.0
    static let defaultPositionY = 0.85

    static let outlinedStrokeWidth = 0.08
    static let maximumStrokeWidth = 0.2
    static let subtitleFontSize = 54.0
    static let subtitlePositionY = 0.88

    static func subtitle(
        _ content: String, style: TextStylePreset = .classic,
        animation: TextAnimation = TextAnimation()
    ) -> TextLayer {
        var layer = TextLayer(
            content: content, fontSize: subtitleFontSize, positionY: subtitlePositionY)
        style.apply(to: &layer)
        layer.animation = animation
        return layer
    }

    var content: String
    var fontName = TextLayer.defaultFontName
    var fontSize = TextLayer.defaultFontSize
    var color = RGBAColor.white
    var positionX = 0.5
    var positionY = TextLayer.defaultPositionY
    var rotationInDegrees = 0.0
    var strokeWidth = 0.0
    var strokeColor = RGBAColor.black
    var backgroundColor: RGBAColor?
    var hasShadow = true
    var animation = TextAnimation()
}

extension TextLayer {
    private enum CodingKeys: String, CodingKey {
        case content, fontName, fontSize, color, positionX, positionY, rotationInDegrees
        case strokeWidth, strokeColor, backgroundColor, hasShadow, animation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        color = try container.decode(RGBAColor.self, forKey: .color)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        rotationInDegrees =
            try container.decodeIfPresent(Double.self, forKey: .rotationInDegrees) ?? 0
        strokeWidth = try container.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? 0
        strokeColor = try container.decodeIfPresent(RGBAColor.self, forKey: .strokeColor) ?? .black
        backgroundColor = try container.decodeIfPresent(RGBAColor.self, forKey: .backgroundColor)
        hasShadow = try container.decodeIfPresent(Bool.self, forKey: .hasShadow) ?? true
        animation =
            try container.decodeIfPresent(TextAnimation.self, forKey: .animation) ?? TextAnimation()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(color, forKey: .color)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        if rotationInDegrees != 0 {
            try container.encode(rotationInDegrees, forKey: .rotationInDegrees)
        }
        if strokeWidth != 0 {
            try container.encode(strokeWidth, forKey: .strokeWidth)
            try container.encode(strokeColor, forKey: .strokeColor)
        }
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        if !hasShadow { try container.encode(hasShadow, forKey: .hasShadow) }
        if !animation.isNone { try container.encode(animation, forKey: .animation) }
    }
}
