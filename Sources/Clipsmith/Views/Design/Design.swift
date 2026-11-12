import SwiftUI

enum Design {
    enum Spacing {
        static let hairline: CGFloat = 2
        static let tight: CGFloat = 4
        static let compact: CGFloat = 6
        static let regular: CGFloat = 8
        static let cozy: CGFloat = 10
        static let comfortable: CGFloat = 12
        static let spacious: CGFloat = 16
        static let roomy: CGFloat = 20

        static let scale = [hairline, tight, compact, regular, cozy, comfortable, spacious, roomy]
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
        static let extraLarge: CGFloat = 12

        static let scale = [small, medium, large, extraLarge]
    }

    enum Opacity {
        static let hitArea = 0.001
        static let subtleBorder = 0.25
        static let handle = 0.35
        static let scrim = 0.55
        static let clipFill = 0.55
        static let outline = 0.6
        static let emphasizedFill = 0.65
        static let waveform = 0.55
        static let selectedOutline = 0.9
        static let missingFill = 0.45
        static let highlightBand = 0.8
        static let sheen = 0.18
        static let hiddenLane = 0.4
        static let tintBadge = 0.15
        static let filmstrip = 0.85
        static let highlightBackground = 0.12
        static let chipFill = 0.08
        static let selectedChipFill = 0.25
    }

    enum IconSize {
        static let emptyState: CGFloat = 36
        static let badge: CGFloat = 9
        static let keyframeMark: CGFloat = 7
    }

    enum Motion {
        static let quick = 0.15
        static let standard = 0.25
    }

    enum Size {
        static let minimumHitTarget: CGFloat = 24
        static let sectionIcon: CGFloat = 18
        static let valueField: CGFloat = 56
        static let playButton: CGFloat = 28
        static let headerBadge: CGFloat = 32
        static let emptyStateMinimumHeight: CGFloat = 160
        static let presetColumn: CGFloat = 72
        static let highlightBand: CGFloat = 5
    }
}
