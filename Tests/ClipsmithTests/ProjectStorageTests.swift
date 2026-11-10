import XCTest
@testable import Clipsmith

final class ProjectStorageTests: XCTestCase {
    private var directory: URL!
    private let storage = ProjectStorage()

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testSavedProjectLoadsBackIdentical() throws {
        let media = try makeFile("clip.mov")
        let (project, library) = makeProject(using: media)
        let destination = directory.appendingPathComponent("p.clipsmith")

        try storage.write(project: project, library: library, to: destination)
        let loaded = try storage.read(from: destination)

        XCTAssertEqual(loaded.project, project)
        XCTAssertEqual(loaded.library, library)
        XCTAssertTrue(loaded.missingMedia.isEmpty)
    }

    func testWrittenFileIsReadableJsonWithTheCurrentVersion() throws {
        let media = try makeFile("clip.mov")
        let (project, library) = makeProject(using: media)
        let destination = directory.appendingPathComponent("p.clipsmith")

        try storage.write(project: project, library: library, to: destination)

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: destination)) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, ProjectFile.currentVersion)
        XCTAssertNotNil(object?["project"])
    }

    func testMissingFilesAreReportedAndKeepTheirPath() throws {
        let media = try makeFile("clip.mov")
        let (project, library) = makeProject(using: media)
        let destination = directory.appendingPathComponent("p.clipsmith")
        try storage.write(project: project, library: library, to: destination)
        try FileManager.default.removeItem(at: media)

        let loaded = try storage.read(from: destination)

        XCTAssertEqual(loaded.missingMedia.map(\.lastPathComponent), ["clip.mov"])
        XCTAssertEqual(loaded.project.referencedSourceURLs.map(\.lastPathComponent), ["clip.mov"])
    }

    func testMovedFilesAreFoundThroughTheirBookmark() throws {
        let media = try makeFile("clip.mov")
        let (project, library) = makeProject(using: media)
        let destination = directory.appendingPathComponent("p.clipsmith")
        try storage.write(project: project, library: library, to: destination)
        let movedFolder = directory.appendingPathComponent("moved")
        try FileManager.default.createDirectory(at: movedFolder, withIntermediateDirectories: true)
        let movedMedia = movedFolder.appendingPathComponent("renamed.mov")
        try FileManager.default.moveItem(at: media, to: movedMedia)

        let loaded = try storage.read(from: destination)

        XCTAssertTrue(loaded.missingMedia.isEmpty)
        XCTAssertEqual(loaded.project.referencedSourceURLs.map(\.lastPathComponent), ["renamed.mov"])
        XCTAssertEqual(loaded.library.map(\.url.lastPathComponent), ["renamed.mov"])
    }

    func testReadingAnUnknownFileFails() {
        let url = directory.appendingPathComponent("nope.clipsmith")

        XCTAssertThrowsError(try storage.read(from: url))
    }

    func testReadingNonProjectDataFailsAsCorrupted() throws {
        let url = directory.appendingPathComponent("bad.clipsmith")
        try Data("hello".utf8).write(to: url)

        XCTAssertThrowsError(try storage.read(from: url)) { error in
            guard case ProjectFileError.corrupted = error else { return XCTFail("Unexpected \(error)") }
        }
    }

    func testRecoveryStoreSavesLoadsAndClears() throws {
        let media = try makeFile("clip.mov")
        let (project, library) = makeProject(using: media)
        let recovery = RecoveryStore(fileURL: directory.appendingPathComponent("rec/Recovery.clipsmith"))
        XCTAssertFalse(recovery.hasRecovery)

        try recovery.save(project: project, library: library)
        XCTAssertTrue(recovery.hasRecovery)
        XCTAssertEqual(try recovery.load().project, project)

        recovery.clear()
        XCTAssertFalse(recovery.hasRecovery)
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("media".utf8).write(to: url)
        return url
    }

    private func makeProject(using media: URL) -> (Project, [MediaItem]) {
        var project = Project(name: "Saved")
        let item = MediaItem(url: media, kind: .video, durationInSeconds: 10)
        project.addClip(Clip(item: item, startInSeconds: 0), toTrack: project.track(withRole: .main)!.id)
        project.addTextClip(TextLayer(content: "Hello"), at: 1, duration: 2)
        return (project, [item])
    }
}
