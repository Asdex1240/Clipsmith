import SwiftUI

struct AddFramingKeyframeButton: View {
    let store: ProjectStore
    let highlight: Highlight

    var body: some View {
        Button(localized("highlight.framing.addKeyframe")) {
            store.addFramingKeyframeAtPlayhead(to: highlight.id)
        }
        .disabled(!playheadIsInside)
    }

    private var playheadIsInside: Bool {
        store.playheadInSeconds >= highlight.startInSeconds
            && store.playheadInSeconds <= highlight.endInSeconds
    }
}

#Preview {
    let store = PreviewFixtures.store()
    let id = store.addHighlight(from: 0, to: 6)
    if let id, let highlight = store.project.highlight(withID: id) {
        AddFramingKeyframeButton(store: store, highlight: highlight)
            .padding()
    }
}
