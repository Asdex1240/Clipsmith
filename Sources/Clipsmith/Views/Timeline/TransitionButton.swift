import SwiftUI

struct TransitionButton: View {
    let store: ProjectStore
    let clip: Clip

    static let size: CGFloat = 16
    private static let durations: [TimeInterval] = [0.5, 1, 1.5, 2]

    private var iconName: String {
        if clip.transition == nil { return "plus" }
        return "arrow.triangle.merge"
    }

    private var iconColor: Color {
        if clip.transition == nil { return .secondary }
        return .white
    }

    private var badgeColor: Color {
        if clip.transition == nil { return Color.black.opacity(0.55) }
        return .accentColor
    }

    var body: some View {
        Menu {
            Button(localized("transition.none")) { store.setTransition(of: clip.id, to: nil) }
                .disabled(clip.transition == nil)
            Divider()
            ForEach(TransitionKind.allCases, id: \.self) { kind in
                Toggle(
                    Self.title(of: kind),
                    isOn: Binding(
                        get: { clip.transition?.kind == kind },
                        set: { _ in choose(kind) }
                    ))
            }
            if let transition = clip.transition {
                Divider()
                Picker(
                    localized("transition.duration"),
                    selection: Binding(
                        get: { transition.durationInSeconds },
                        set: {
                            store.setTransition(of: clip.id, to: transition.settingDuration($0))
                        }
                    )
                ) {
                    ForEach(Self.durations, id: \.self) { Text(String(format: "%g s", $0)).tag($0) }
                }
                Picker(
                    localized("easing.title"),
                    selection: Binding(
                        get: { transition.easing },
                        set: { store.setTransition(of: clip.id, to: transition.settingEasing($0)) }
                    )
                ) {
                    ForEach(Easing.allCases, id: \.self) { Text(EasingMenu.title(of: $0)).tag($0) }
                }
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(badgeColor))
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(helpText)
    }

    private var helpText: String {
        guard let transition = clip.transition else { return localized("transition.add") }
        let duration = String(format: "%g s", transition.durationInSeconds)
        return "\(Self.title(of: transition.kind)) · \(duration)"
    }

    private func choose(_ kind: TransitionKind) {
        let duration = clip.transition?.durationInSeconds ?? ClipTransition.defaultDuration
        store.setTransition(
            of: clip.id, to: ClipTransition(kind: kind, durationInSeconds: duration))
    }

    static func title(of kind: TransitionKind) -> String {
        switch kind {
        case .dissolve: return localized("transition.dissolve")
        case .fadeBlack: return localized("transition.fadeBlack")
        case .slideLeft: return localized("transition.slideLeft")
        case .slideRight: return localized("transition.slideRight")
        }
    }
}

#Preview {
    TransitionButton(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
