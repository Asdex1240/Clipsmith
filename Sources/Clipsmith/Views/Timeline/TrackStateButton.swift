import SwiftUI

struct TrackStateButton: View {
    let activeImage: String
    let inactiveImage: String
    let isActive: Bool
    let activeLabel: String
    let inactiveLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: Design.Size.sectionIcon)
                .foregroundStyle(tint)
                .minimumHitTarget()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(traits)
    }

    private var symbol: String {
        if isActive { return activeImage }
        return inactiveImage
    }

    private var label: String {
        if isActive { return activeLabel }
        return inactiveLabel
    }

    private var tint: Color {
        if isActive { return Palette.warningText }
        return .secondary
    }

    private var traits: AccessibilityTraits {
        if isActive { return .isSelected }
        return []
    }
}

#Preview {
    HStack {
        TrackStateButton(
            activeImage: "speaker.slash.fill", inactiveImage: "speaker.wave.2", isActive: true,
            activeLabel: "Unmute", inactiveLabel: "Mute", action: {})
        TrackStateButton(
            activeImage: "lock.fill", inactiveImage: "lock.open", isActive: false,
            activeLabel: "Unlock", inactiveLabel: "Lock", action: {})
    }
    .padding()
}
