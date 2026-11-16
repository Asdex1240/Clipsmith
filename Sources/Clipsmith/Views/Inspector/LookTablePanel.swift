import AppKit
import UniformTypeIdentifiers

@MainActor
enum LookTablePanel {
    private static let cubeExtension = "cube"

    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: cubeExtension) ?? .data]
        panel.prompt = localized("inspector.look.lut.choose")
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
