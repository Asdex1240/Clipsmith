import AppKit
import SwiftUI

enum Palette {
    static let selection = adaptive(
        light: NSColor(srgbRed: 0.85, green: 0.6, blue: 0, alpha: 1), dark: .systemYellow)
    static let keyframe = selection
    static let marker = Color.orange
    static let warning = Color.orange
    static let success = Color.green
    static let invalid = Color.red
    static let playhead = Color.red
    static let guideEdge = Color.red
    static let guideCenter = Color.cyan
    static let onMedia = Color.white
    static let scrim = Color.black

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
