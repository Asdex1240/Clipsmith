import SwiftUI

struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private static let width: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("shortcuts.title")).font(.title2.bold())
            ForEach(EditorAction.allCases, id: \.self) { action in
                HStack {
                    Text(title(of: action))
                    Spacer()
                    Text(EditorShortcuts.displayKeys(for: action))
                        .monospaced()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            HStack {
                Spacer()
                Button(localized("export.close")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: Self.width)
    }

    private func title(of action: EditorAction) -> String {
        switch action {
        case .togglePlayback: return localized("shortcut.togglePlayback")
        case .split: return localized("timeline.split")
        case .addText: return localized("timeline.addText")
        case .addMarker: return localized("timeline.addMarker")
        case .delete: return localized("timeline.delete")
        case .rippleDelete: return localized("timeline.rippleDelete")
        case .zoomIn: return localized("timeline.zoomIn")
        case .zoomOut: return localized("timeline.zoomOut")
        case .stepBackward: return localized("shortcut.stepBackward")
        case .stepForward: return localized("shortcut.stepForward")
        case .jumpBackward: return localized("shortcut.jumpBackward")
        case .jumpForward: return localized("shortcut.jumpForward")
        case .previousEdit: return localized("shortcut.previousEdit")
        case .nextEdit: return localized("shortcut.nextEdit")
        case .goToStart: return localized("shortcut.goToStart")
        case .goToEnd: return localized("shortcut.goToEnd")
        case .deselect: return localized("shortcut.deselect")
        }
    }
}
