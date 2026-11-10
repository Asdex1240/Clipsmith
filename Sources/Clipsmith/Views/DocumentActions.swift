import AppKit
import UniformTypeIdentifiers

@MainActor
struct DocumentActions {
    let document: DocumentController

    private static var projectType: UTType {
        UTType(filenameExtension: DocumentController.fileExtension, conformingTo: .json) ?? .json
    }

    func newProject() {
        guard confirmDiscardingChanges() else { return }
        document.newProject()
    }

    func openProject() {
        guard confirmDiscardingChanges() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.projectType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        document.open(url)
    }

    @discardableResult
    func save() -> Bool {
        document.fileURL == nil ? saveAs() : document.save()
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.projectType]
        panel.nameFieldStringValue = document.windowTitleName + "." + DocumentController.fileExtension
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return document.save(to: url)
    }

    func locateReplacement(for missing: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.message = String(format: localized("relink.panel.message"), missing.lastPathComponent)
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    func confirmDiscardingChanges() -> Bool {
        guard document.hasUnsavedChanges else {
            document.discardChangesForQuit()
            return true
        }
        let alert = NSAlert()
        alert.messageText = String(format: localized("document.unsaved.title"), document.windowTitleName)
        alert.informativeText = localized("document.unsaved.message")
        alert.addButton(withTitle: localized("document.unsaved.save"))
        alert.addButton(withTitle: localized("document.unsaved.discard"))
        alert.addButton(withTitle: localized("document.unsaved.cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save()
        case .alertSecondButtonReturn:
            document.discardChangesForQuit()
            return true
        default:
            return false
        }
    }
}
