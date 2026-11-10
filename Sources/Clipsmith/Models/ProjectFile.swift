import Foundation

struct ProjectFile: Codable, Equatable {
    static let currentVersion = 1

    var version = ProjectFile.currentVersion
    var project: Project
    var library: [MediaItem]
    var bookmarks: [String: Data]
}

enum ProjectFileError: Error, LocalizedError {
    case corrupted
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .corrupted:
            return localized("error.file.corrupted")
        case .unsupportedVersion(let version):
            return String(format: localized("error.file.unsupportedVersion"), version)
        }
    }
}

enum ProjectFileCoding {
    private struct Header: Decodable {
        let version: Int
    }

    static func encode(_ file: ProjectFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> ProjectFile {
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else {
            throw ProjectFileError.corrupted
        }
        guard header.version <= ProjectFile.currentVersion else {
            throw ProjectFileError.unsupportedVersion(header.version)
        }
        guard let file = try? decoder.decode(ProjectFile.self, from: data) else {
            throw ProjectFileError.corrupted
        }
        return file
    }
}
