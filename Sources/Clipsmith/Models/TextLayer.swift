import Foundation

struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let white = RGBAColor(red: 1, green: 1, blue: 1)
}

struct TextLayer: Codable, Equatable {
    static let referenceShortSide = 1080.0
    static let defaultFontName = "HelveticaNeue-Bold"
    static let defaultFontSize = 72.0
    static let defaultPositionY = 0.85

    var content: String
    var fontName = TextLayer.defaultFontName
    var fontSize = TextLayer.defaultFontSize
    var color = RGBAColor.white
    var positionX = 0.5
    var positionY = TextLayer.defaultPositionY
    /// Clockwise rotation around the text's center, in degrees.
    var rotationInDegrees = 0.0
}

extension TextLayer {
    private enum CodingKeys: String, CodingKey {
        case content, fontName, fontSize, color, positionX, positionY, rotationInDegrees
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        color = try container.decode(RGBAColor.self, forKey: .color)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        rotationInDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationInDegrees) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(color, forKey: .color)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        if rotationInDegrees != 0 { try container.encode(rotationInDegrees, forKey: .rotationInDegrees) }
    }
}
