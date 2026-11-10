import Foundation

struct RecoveryStore {
    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipsmith", isDirectory: true)
            .appendingPathComponent("Recovery.clipsmith")
    }

    var fileURL = RecoveryStore.defaultFileURL
    var storage: ProjectStoring = ProjectStorage()

    var hasRecovery: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func save(project: Project, library: [MediaItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try storage.write(project: project, library: library, to: fileURL)
    }

    func load() throws -> LoadedProject {
        try storage.read(from: fileURL)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
