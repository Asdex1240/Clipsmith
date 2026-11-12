import SwiftUI

struct PreviewProjectStorage: ProjectStoring {
    func write(project: Project, library: [MediaItem], to url: URL) throws {}

    func read(from url: URL) throws -> LoadedProject {
        throw CocoaError(.fileReadUnknown)
    }
}
