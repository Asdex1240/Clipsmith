import SwiftUI

struct TimelineToolbar: View {
    let store: ProjectStore

    private var snappingTitle: String {
        if store.isSnappingEnabled { return localized("timeline.snapping.on") }
        return localized("timeline.snapping.off")
    }

    var body: some View {
        HStack(spacing: Design.Spacing.comfortable) {
            Text(store.project.name).font(.headline).lineLimit(1)
            Text(store.playheadInSeconds.clockString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            insertGroup
            cutGroup
            clipGroup
            deleteGroup
            zoomGroup
        }
        .padding(.horizontal, Design.Spacing.regular)
        .padding(.vertical, Design.Spacing.tight)
    }

    private var insertGroup: some View {
        TimelineToolGroup {
            Toggle(
                isOn: Binding(
                    get: { store.isSnappingEnabled }, set: { _ in store.toggleSnapping() })
            ) {
                Image(systemName: "magnet")
            }
            .toggleStyle(.button)
            .accessibilityLabel(snappingTitle)
            .help("\(snappingTitle) (\(EditorShortcuts.displayKeys(for: .toggleSnapping)))")
            button(
                "timeline.addText", systemImage: "textformat", shortcut: .addText,
                action: store.addTextAtPlayhead)
            button(
                "timeline.addMarker", systemImage: "bookmark", shortcut: .addMarker,
                action: store.toggleMarkerAtPlayhead)
        }
    }

    private var cutGroup: some View {
        TimelineToolGroup {
            button(
                "timeline.split", systemImage: "scissors", shortcut: .split,
                action: store.splitAtPlayhead)
            button(
                "shortcut.trimStart", systemImage: "arrow.right.to.line",
                shortcut: .trimStartToPlayhead
            ) {
                store.trimToPlayhead(edge: .leading)
            }
            button(
                "shortcut.trimEnd", systemImage: "arrow.left.to.line.compact",
                shortcut: .trimEndToPlayhead
            ) {
                store.trimToPlayhead(edge: .trailing)
            }
        }
    }

    private var clipGroup: some View {
        TimelineToolGroup {
            button(
                "shortcut.duplicate", systemImage: "plus.square.on.square", shortcut: .duplicate,
                action: store.duplicateSelectedClip)
            button(
                "timeline.group", systemImage: "link", shortcut: .group,
                action: store.groupSelection
            )
            .disabled(!store.canGroupSelection)
            button(
                "timeline.ungroup", systemImage: "link.badge.plus", shortcut: .ungroup,
                action: store.ungroupSelection
            )
            .disabled(!store.selectionIsGrouped)
        }
    }

    private var deleteGroup: some View {
        TimelineToolGroup {
            button(
                "timeline.delete", systemImage: "trash", shortcut: .delete,
                action: store.deleteSelectedClip)
            button(
                "timeline.rippleDelete", systemImage: "arrow.left.to.line",
                shortcut: .rippleDelete, action: store.rippleDeleteSelectedClip)
        }
    }

    private var zoomGroup: some View {
        TimelineToolGroup {
            button(
                "timeline.zoomOut", systemImage: "minus.magnifyingglass", shortcut: .zoomOut,
                action: store.zoomOut)
            button(
                "timeline.zoomIn", systemImage: "plus.magnifyingglass", shortcut: .zoomIn,
                action: store.zoomIn)
        }
    }

    private func button(
        _ key: String.LocalizationValue,
        systemImage: String,
        shortcut: EditorAction,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Image(systemName: systemImage).minimumHitTarget() }
            .accessibilityLabel(localized(key))
            .help("\(localized(key)) (\(EditorShortcuts.displayKeys(for: shortcut)))")
    }
}

#Preview {
    TimelineToolbar(store: PreviewFixtures.store())
        .frame(width: 900)
}
