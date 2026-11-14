import SwiftUI

struct BackgroundInspector: View, Equatable {
    let store: ProjectStore
    let clip: Clip

    static func == (lhs: BackgroundInspector, rhs: BackgroundInspector) -> Bool {
        lhs.store === rhs.store && lhs.clip.id == rhs.clip.id
            && lhs.clip.backgroundEffect == rhs.clip.backgroundEffect
    }

    var body: some View {
        InspectorSection(.background) {
            Picker(localized("inspector.background.section"), selection: effectBinding) {
                Text(localized("inspector.background.none")).tag(BackgroundEffect?.none)
                ForEach(BackgroundEffect.allCases) { effect in
                    Text(localized(String.LocalizationValue(effect.titleKey)))
                        .tag(Optional(effect))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(localized("inspector.background.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var effectBinding: Binding<BackgroundEffect?> {
        Binding(
            get: { clip.backgroundEffect },
            set: { store.setBackgroundEffect(of: clip.id, to: $0) }
        )
    }
}

#Preview {
    BackgroundInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
        .frame(width: 280)
}
