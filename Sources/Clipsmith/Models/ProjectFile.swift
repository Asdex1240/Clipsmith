import Foundation

struct ProjectFile: Codable, Equatable {
    static let currentVersion = 2

    var version = ProjectFile.currentVersion
    var project: Project
    var library: [MediaItem]
    var bookmarks: [String: Data]
}
