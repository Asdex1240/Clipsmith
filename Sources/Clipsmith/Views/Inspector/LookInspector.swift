import SwiftUI

struct LookInspector: View, Equatable {
    let store: ProjectStore
    let clip: Clip
    @State private var errorMessage: String?

    private static let neutral = LookEffects()

    static func == (lhs: LookInspector, rhs: LookInspector) -> Bool {
        lhs.store === rhs.store && lhs.clip.id == rhs.clip.id && lhs.clip.look == rhs.clip.look
    }

    var body: some View {
        InspectorSection(.look) {
            lookSlider("inspector.look.grain", \.grain)
            lookSlider("inspector.look.vignette", \.vignette)
            lookSlider("inspector.look.sharpness", \.sharpness)
            Divider()
            lookTableControls
            Button(localized("inspector.look.reset")) {
                store.setLook(of: clip.id, to: Self.neutral)
            }
            .disabled(clip.look.isNone)
        }
    }

    @ViewBuilder
    private var lookTableControls: some View {
        Text(localized("inspector.look.lut")).font(.subheadline)
        if let reference = clip.look.lookTable {
            HStack {
                Label(reference.name, systemImage: "cube")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(localized("inspector.look.lut.remove")) {
                    store.removeLookTable(from: clip.id)
                }
            }
            ParameterSlider(
                title: localized("inspector.look.lut.intensity"), value: intensityBinding,
                range: LookEffects.amountRange, unit: .percent, defaultValue: 1)
        }
        Button(localized("inspector.look.lut.choose"), action: chooseLookTable)
        if let errorMessage {
            Text(errorMessage).font(.caption).foregroundStyle(Palette.warningText)
        }
        Text(localized("inspector.look.lut.hint")).font(.caption).foregroundStyle(.secondary)
    }

    private func chooseLookTable() {
        guard let url = LookTablePanel.choose() else { return }
        do {
            try store.applyLookTable(at: url, to: clip.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func lookSlider(
        _ key: String.LocalizationValue, _ path: WritableKeyPath<LookEffects, Double>
    ) -> some View {
        ParameterSlider(
            title: localized(key),
            value: Binding(
                get: { clip.look[keyPath: path] },
                set: { newValue in
                    var look = clip.look
                    look[keyPath: path] = newValue
                    store.setLook(of: clip.id, to: look)
                }
            ),
            range: LookEffects.amountRange, unit: .percent, defaultValue: 0)
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { clip.look.lookTable?.intensity ?? 1 },
            set: { newValue in
                var look = clip.look
                look.lookTable?.intensity = newValue
                store.setLook(of: clip.id, to: look)
            }
        )
    }
}

#Preview {
    LookInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
        .frame(width: 280)
}
