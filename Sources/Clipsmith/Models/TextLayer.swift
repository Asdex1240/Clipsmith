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
}
