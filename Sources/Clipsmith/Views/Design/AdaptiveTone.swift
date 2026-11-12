import AppKit
import SwiftUI

struct AdaptiveTone: Equatable {
    let light: RGBAColor
    let dark: RGBAColor

    var color: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark { return Self.nsColor(dark) }
                return Self.nsColor(light)
            })
    }

    private static func nsColor(_ tone: RGBAColor) -> NSColor {
        NSColor(srgbRed: tone.red, green: tone.green, blue: tone.blue, alpha: tone.alpha)
    }
}
