import SwiftUI

struct InspectorView: View {
    let store: ProjectStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localized("panel.inspector"))
                .font(.headline)
                .padding(8)
            Divider()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let clip = store.selectedClip {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if clip.textLayer != nil {
                        TextInspector(store: store, clip: clip)
                    }
                    if hasAudioControls(for: clip) {
                        AudioInspector(store: store, clip: clip)
                    }
                }
                .padding(12)
            }
        } else {
            ZStack {
                Rectangle().fill(.background.secondary)
                Text(localized("inspector.empty"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }

    private func hasAudioControls(for clip: Clip) -> Bool {
        guard clip.mediaKind == .video || clip.mediaKind == .audio else { return false }
        return store.project.trackRole(ofClip: clip.id)?.playsAudio ?? false
    }
}
