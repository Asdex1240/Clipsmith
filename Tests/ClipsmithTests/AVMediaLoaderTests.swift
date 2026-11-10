import AVFoundation
import XCTest
@testable import Clipsmith

final class AVMediaLoaderTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporaryDirectory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testLoadsDurationOfAnAudioFile() async throws {
        let url = try makeSilentWav(seconds: 2)

        let item = try await AVMediaLoader().loadItem(from: url)

        XCTAssertEqual(item.kind, .audio)
        XCTAssertEqual(item.durationInSeconds, 2, accuracy: 0.05)
    }

    func testImagesGetTheStillImageDuration() async throws {
        let url = temporaryDirectory.appendingPathComponent("photo.png")
        try Data().write(to: url)

        let item = try await AVMediaLoader().loadItem(from: url)

        XCTAssertEqual(item.kind, .image)
        XCTAssertEqual(item.durationInSeconds, AVMediaLoader.stillImageDurationInSeconds)
    }

    func testRejectsUnsupportedFormat() async throws {
        let url = temporaryDirectory.appendingPathComponent("notes.txt")
        try Data().write(to: url)

        await assertThrowsUnsupportedFormat(url)
    }

    func testReportsUnreadableMedia() async throws {
        let url = temporaryDirectory.appendingPathComponent("broken.mp4")
        try Data("not a video".utf8).write(to: url)

        do {
            _ = try await AVMediaLoader().loadItem(from: url)
            XCTFail("Expected an unreadable error")
        } catch ImportError.unreadable {
        }
    }

    private func assertThrowsUnsupportedFormat(_ url: URL) async {
        do {
            _ = try await AVMediaLoader().loadItem(from: url)
            XCTFail("Expected an unsupported format error")
        } catch ImportError.unsupportedFormat {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSilentWav(seconds: Double) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent("silence.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let frameCount = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
