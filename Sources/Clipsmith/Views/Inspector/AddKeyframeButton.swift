import SwiftUI

struct AddKeyframeButton: View {
    let store: ProjectStore
    let clip: Clip

    var body: some View {
        Button(localized("inspector.keyframes.add")) {
            store.addKeyframeAtPlayhead(to: clip.id)
        }
        .disabled(!playheadIsInsideClip)
    }

    private var playheadIsInsideClip: Bool {
        store.playheadInSeconds >= clip.startInSeconds
            && store.playheadInSeconds <= clip.endInSeconds
    }
}

#Preview {
    AddKeyframeButton(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
