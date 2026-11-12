import SwiftUI

struct MainToolbar: ToolbarContent {
    let store: ProjectStore
    let documentActions: DocumentActions
    @Binding var isSidebarVisible: Bool
    @Binding var isInspectorVisible: Bool
    let onExport: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                isSidebarVisible.toggle()
            } label: {
                Label(localized("toolbar.sidebar"), systemImage: "sidebar.left")
            }
            .keyboardShortcut("1", modifiers: [.command, .option])
            .help(localized("toolbar.sidebar"))
        }
        ToolbarItemGroup(placement: .automatic) {
            ControlGroup {
                Button(action: documentActions.newProject) {
                    Label(localized("menu.new"), systemImage: "doc.badge.plus")
                }
                Button(action: documentActions.openProject) {
                    Label(localized("menu.open"), systemImage: "folder")
                }
                Button(action: { documentActions.save() }) {
                    Label(localized("menu.save"), systemImage: "square.and.arrow.down")
                }
            }
            ControlGroup {
                Button(action: store.undo) {
                    Label(localized("menu.undo"), systemImage: "arrow.uturn.backward")
                }
                .disabled(!store.canUndo)
                Button(action: store.redo) {
                    Label(localized("menu.redo"), systemImage: "arrow.uturn.forward")
                }
                .disabled(!store.canRedo)
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isInspectorVisible.toggle()
            } label: {
                Label(localized("toolbar.inspector"), systemImage: "sidebar.right")
            }
            .keyboardShortcut("2", modifiers: [.command, .option])
            .help(localized("toolbar.inspector"))
            Button(action: onExport) {
                Label(localized("export.open"), systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(store.project.durationInSeconds == 0)
        }
    }
}
