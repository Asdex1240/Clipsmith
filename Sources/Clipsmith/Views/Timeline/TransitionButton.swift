import SwiftUI

struct TransitionButton: View {
    let store: ProjectStore
    let clip: Clip

    static let size: CGFloat = 16
    private static let durations: [TimeInterval] = [0.5, 1, 1.5, 2]

    var body: some View {
        Menu {
            Button(localized("transition.none")) { store.setTransition(of: clip.id, to: nil) }
                .disabled(clip.transition == nil)
            Divider()
            ForEach(TransitionKind.allCases, id: \.self) { kind in
                Toggle(Self.title(of: kind), isOn: Binding(
                    get: { clip.transition?.kind == kind },
                    set: { _ in choose(kind) }
                ))
            }
            if let transition = clip.transition {
                Divider()
                Picker(localized("transition.duration"), selection: Binding(
                    get: { transition.durationInSeconds },
                    set: { store.setTransition(of: clip.id, to: transition.settingDuration($0)) }
                )) {
                    ForEach(Self.durations, id: \.self) { Text(String(format: "%g s", $0)).tag($0) }
                }
                Picker(localized("easing.title"), selection: Binding(
                    get: { transition.easing },
                    set: { store.setTransition(of: clip.id, to: transition.settingEasing($0)) }
                )) {
                    ForEach(Easing.allCases, id: \.self) { Text(EasingMenu.title(of: $0)).tag($0) }
                }
            }
        } label: {
            Image(systemName: clip.transition == nil ? "plus" : "arrow.triangle.merge")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(clip.transition == nil ? Color.secondary : Color.white)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(clip.transition == nil ? Color.black.opacity(0.55) : Color.accentColor))
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
        return "\(Self.title(of: transition.kind)) · \(String(format: "%g s", transition.durationInSeconds))"
    }

    private func choose(_ kind: TransitionKind) {
        let duration = clip.transition?.durationInSeconds ?? ClipTransition.defaultDuration
        store.setTransition(of: clip.id, to: ClipTransition(kind: kind, durationInSeconds: duration))
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
