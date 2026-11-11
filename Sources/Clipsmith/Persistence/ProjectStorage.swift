import Foundation

struct ProjectStorage: ProjectStoring {
    func write(project: Project, library: [MediaItem], to url: URL) throws {
        let urls = project.referencedSourceURLs.union(library.map(\.url))
        let bookmarks = urls.reduce(into: [String: Data]()) { result, url in
            result[url.path] = MediaBookmarks.makeBookmark(for: url)
        }
        let file = ProjectFile(project: project, library: library, bookmarks: bookmarks)
        try ProjectFileCoding.encode(file).write(to: url, options: .atomic)
    }

    func read(from url: URL) throws -> LoadedProject {
        let file = try ProjectFileCoding.decode(Data(contentsOf: url))
        let urls = file.project.referencedSourceURLs.union(file.library.map(\.url))
        let resolutions = urls.reduce(into: [URL: MediaBookmarks.Resolution]()) {
            result, original in
            result[original] = MediaBookmarks.resolve(
                original: original, bookmark: file.bookmarks[original.path])
        }
        let replacements = resolutions.mapValues(\.url)
        var project = file.project
        project.remapSources(replacements)
        let missing = resolutions.values.filter { !$0.exists }.map(\.url).sorted {
            $0.path < $1.path
        }
        return LoadedProject(
            project: project,
            library: file.library.map { $0.remapped(replacements) },
            missingMedia: missing
        )
    }
}
