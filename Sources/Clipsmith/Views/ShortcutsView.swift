import SwiftUI

struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private static let width: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
            Text(localized("shortcuts.title")).font(.title2.bold())
            ForEach(EditorAction.allCases, id: \.self) { action in
                HStack {
                    Text(title(of: action))
                    Spacer()
                    Text(EditorShortcuts.displayKeys(for: action))
                        .monospaced()
                        .padding(.horizontal, Design.Spacing.compact)
                        .padding(.vertical, Design.Spacing.hairline)
                        .background(
                            .quaternary, in: RoundedRectangle(cornerRadius: Design.Radius.small))
                }
            }
            HStack {
                Spacer()
                Button(localized("export.close")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Design.Spacing.roomy)
        .frame(width: Self.width)
    }

    private func title(of action: EditorAction) -> String {
        switch action {
        case .togglePlayback: return localized("shortcut.togglePlayback")
        case .split: return localized("timeline.split")
        case .addText: return localized("timeline.addText")
        case .addMarker: return localized("timeline.addMarker")
        case .toggleSnapping: return localized("timeline.snapping")
        case .markHighlightStart: return localized("shortcut.markHighlightStart")
        case .markHighlightEnd: return localized("shortcut.markHighlightEnd")
        case .addHighlight: return localized("shortcut.addHighlight")
        case .delete: return localized("timeline.delete")
        case .rippleDelete: return localized("timeline.rippleDelete")
        case .trimStartToPlayhead: return localized("shortcut.trimStart")
        case .trimEndToPlayhead: return localized("shortcut.trimEnd")
        case .copy: return localized("shortcut.copy")
        case .cut: return localized("shortcut.cut")
        case .paste: return localized("shortcut.paste")
        case .duplicate: return localized("shortcut.duplicate")
        case .selectAll: return localized("shortcut.selectAll")
        case .group: return localized("timeline.group")
        case .ungroup: return localized("timeline.ungroup")
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

#Preview {
    ShortcutsView()
}
