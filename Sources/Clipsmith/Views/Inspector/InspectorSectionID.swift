import Foundation

enum InspectorSectionID: String, CaseIterable {
    case framing, keyframes, color, crop, text, textStyle, textAnimation, speed, audio, silences, subtitles

    var storageKey: String {
        "inspector.section.\(rawValue)"
    }

    var titleKey: String {
        switch self {
        case .framing: return "inspector.visual.section"
        case .keyframes: return "inspector.keyframes.section"
        case .color: return "inspector.effects.section"
        case .crop: return "inspector.crop.section"
        case .text: return "inspector.text.section"
        case .textStyle: return "inspector.textStyle.section"
        case .textAnimation: return "inspector.textAnimation.section"
        case .speed: return "inspector.speed.section"
        case .audio: return "inspector.audio.section"
        case .silences: return "inspector.silences.section"
        case .subtitles: return "inspector.subtitles.section"
        }
    }

    var systemImage: String {
        switch self {
        case .framing: return "arrow.up.left.and.arrow.down.right"
        case .keyframes: return "diamond"
        case .color: return "paintpalette"
        case .crop: return "crop"
        case .text: return "textformat"
        case .textStyle: return "textformat.size"
        case .textAnimation: return "wand.and.stars"
        case .speed: return "speedometer"
        case .audio: return "speaker.wave.2"
        case .silences: return "waveform.path"
        case .subtitles: return "captions.bubble"
        }
    }
}
