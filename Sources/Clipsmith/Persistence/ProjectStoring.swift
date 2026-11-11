import Foundation

protocol ProjectStoring {
    func write(project: Project, library: [MediaItem], to url: URL) throws
    func read(from url: URL) throws -> LoadedProject
}
