import XCTest
@testable import Clipsmith

final class MediaKindTests: XCTestCase {
    func testRecognizesVideoAudioAndImageExtensions() {
        XCTAssertEqual(MediaKind(url: url("clip.mov")), .video)
        XCTAssertEqual(MediaKind(url: url("clip.MP4")), .video)
        XCTAssertEqual(MediaKind(url: url("song.m4a")), .audio)
        XCTAssertEqual(MediaKind(url: url("song.wav")), .audio)
        XCTAssertEqual(MediaKind(url: url("photo.jpg")), .image)
        XCTAssertEqual(MediaKind(url: url("photo.png")), .image)
    }

    func testRejectsUnsupportedExtensions() {
        XCTAssertNil(MediaKind(url: url("notes.txt")))
        XCTAssertNil(MediaKind(url: url("archive.zip")))
        XCTAssertNil(MediaKind(url: url("noextension")))
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}
