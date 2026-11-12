import AppKit
import SwiftUI

enum Palette {
    static let selection = adaptive(
        light: NSColor(srgbRed: 0.85, green: 0.6, blue: 0, alpha: 1), dark: .systemYellow)
    static let keyframe = selection
    static let marker = Color.orange
    static let highlight = Color.teal
    static let invalid = Color.red
    static let playhead = Color.red
    static let guideEdge = Color.red
    static let guideCenter = Color.cyan
    static let onMedia = Color.white
    static let scrim = Color.black

    static let successTone = AdaptiveTone(
        light: RGBAColor(hex: 0x157033), dark: RGBAColor(hex: 0x4CD964))
    static let warningTone = AdaptiveTone(
        light: RGBAColor(hex: 0x8A5200), dark: RGBAColor(hex: 0xFFB340))
    static let invalidTone = AdaptiveTone(
        light: RGBAColor(hex: 0xB3261E), dark: RGBAColor(hex: 0xFF8A82))

    static let successText = successTone.color
    static let warningText = warningTone.color
    static let invalidText = invalidTone.color

    static func clipFill(for kind: MediaKind) -> Color {
        switch kind {
        case .video: return Color.blue.opacity(Design.Opacity.clipFill)
        case .image: return Color.purple.opacity(Design.Opacity.clipFill)
        case .audio: return Color.green.opacity(Design.Opacity.clipFill)
        case .text: return Color.orange.opacity(Design.Opacity.emphasizedFill)
        }
    }

    static let missingClipFill = invalid.opacity(Design.Opacity.missingFill)

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark { return dark }
                return light
            })
    }
}
