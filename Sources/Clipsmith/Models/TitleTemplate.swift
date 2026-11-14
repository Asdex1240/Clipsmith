import Foundation

enum TitleTemplate: String, CaseIterable, Identifiable {
    case centerTitle, lowerThird, locationTag, chapter, caption

    var id: String { rawValue }

    var durationInSeconds: TimeInterval {
        switch self {
        case .centerTitle: return 4
        case .lowerThird: return 5
        case .locationTag: return 3
        case .chapter: return 3
        case .caption: return 4
        }
    }

    func layer(content: String) -> TextLayer {
        var layer = TextLayer(content: content)
        switch self {
        case .centerTitle:
            layer.fontName = "Futura-Bold"
            layer.fontSize = 120
            layer.positionY = 0.5
            layer.animation = TextAnimation(inKind: .pop, outKind: .fade, durationInSeconds: 0.5)
        case .lowerThird:
            layer.fontName = "AvenirNext-Bold"
            layer.fontSize = 56
            layer.positionY = 0.82
            TextStylePreset.boxed.apply(to: &layer)
            layer.animation = TextAnimation(
                inKind: .slideUp, outKind: .fade, durationInSeconds: 0.45)
        case .locationTag:
            layer.fontName = "Georgia-Bold"
            layer.fontSize = 60
            layer.positionY = 0.12
            TextStylePreset.outlined.apply(to: &layer)
            layer.animation = TextAnimation.both(.fade)
        case .chapter:
            layer.fontName = "Impact"
            layer.fontSize = 150
            layer.positionY = 0.5
            TextStylePreset.highlight.apply(to: &layer)
            layer.animation = TextAnimation(inKind: .pop, outKind: .pop, durationInSeconds: 0.35)
        case .caption:
            layer.fontName = "HelveticaNeue-Bold"
            layer.fontSize = 48
            layer.positionY = 0.9
            layer.animation = TextAnimation.both(.fade)
        }
        return layer
    }
}
