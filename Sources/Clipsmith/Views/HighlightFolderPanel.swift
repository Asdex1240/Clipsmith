import AppKit

@MainActor
enum HighlightFolderPanel {
    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localized("highlight.export.choose")
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
