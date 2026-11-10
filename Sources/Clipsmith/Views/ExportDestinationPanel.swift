import AppKit
import UniformTypeIdentifiers

@MainActor
enum ExportDestinationPanel {
    static func choose(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
