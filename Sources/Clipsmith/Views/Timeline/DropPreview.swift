import SwiftUI

struct DropPreview: Equatable {
    let trackID: Track.ID
    let start: TimeInterval
    let duration: TimeInterval
    let kind: MediaKind
    let name: String
    let isValid: Bool

    var tint: Color {
        if isValid { return .accentColor }
        return .red
    }

    var iconName: String {
        if isValid { return "plus" }
        return "nosign"
    }
}
