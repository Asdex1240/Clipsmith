import SwiftUI

struct StabilizationInspector: View, Equatable {
    let store: ProjectStore
    let clip: Clip

    private let analyzer: StabilizationAnalyzing = VisionStabilizationAnalyzer()
    @State private var strength = StabilizationStrength.normal
    @State private var progress: Double?
    @State private var message: String?

    static func == (lhs: StabilizationInspector, rhs: StabilizationInspector) -> Bool {
        lhs.store === rhs.store && lhs.clip.id == rhs.clip.id
            && lhs.clip.stabilization == rhs.clip.stabilization
            && lhs.clip.sourceStartInSeconds == rhs.clip.sourceStartInSeconds
            && lhs.clip.sourceEndInSeconds == rhs.clip.sourceEndInSeconds
    }

    var body: some View {
        InspectorSection(.stabilization) {
            Picker(localized("inspector.stabilization.strength"), selection: $strength) {
                ForEach(StabilizationStrength.allCases) { strength in
                    Text(localized(String.LocalizationValue(strength.titleKey))).tag(strength)
                }
            }
            .pickerStyle(.segmented)
            HStack {
                Button(localized("inspector.stabilization.apply"), action: apply)
                    .disabled(progress != nil)
                if clip.stabilization != nil {
                    Button(localized("inspector.stabilization.remove")) {
                        message = nil
                        store.clearStabilization(of: clip.id)
                    }
                }
            }
            if let progress {
                ProgressView(value: progress)
                Text(localized("inspector.stabilization.working"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(Palette.warningText)
            }
            Text(localized("inspector.stabilization.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func apply() {
        message = nil
        progress = 0
        Task {
            let applied = await store.stabilizeClip(
                clip.id, strength: strength, using: analyzer
            ) { value in
                Task { @MainActor in progress = value }
            }
            progress = nil
            if !applied { message = localized("inspector.stabilization.none") }
        }
    }
}

#Preview {
    StabilizationInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
        .frame(width: 280)
}
