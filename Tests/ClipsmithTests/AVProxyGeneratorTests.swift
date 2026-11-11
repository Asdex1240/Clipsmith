import AppKit
import AVFoundation
import XCTest
@testable import Clipsmith

final class AVProxyGeneratorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "proxy-av-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeVideo(width: Int, height: Int) async throws -> URL {
        let image = NSImage(size: NSSize(width: 64, height: 36))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 36).fill()
        image.unlockFocus()
        let png = directory.appendingPathComponent("frame-\(width).png")
        let data = try XCTUnwrap(
            NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))?.representation(
                using: .png, properties: [:]))
        try data.write(to: png)
        return try await StillImageVideoWriter(directory: directory).makeVideo(
            from: png, size: CGSize(width: width, height: height), mode: .fit)
    }

    func testOnlyVideosLargerThanFullHDNeedAProxy() async throws {
        let generator = AVProxyGenerator()
        let big = try await makeVideo(width: 3840, height: 2160)
        let small = try await makeVideo(width: 1280, height: 720)

        let bigNeeds = await generator.needsProxy(for: big)
        let smallNeeds = await generator.needsProxy(for: small)

        XCTAssertTrue(bigNeeds)
        XCTAssertFalse(smallNeeds)
    }

    func testTheProxyIsSmallerAndKeepsTheDuration() async throws {
        let source = try await makeVideo(width: 3840, height: 2160)
        let destination = directory.appendingPathComponent("out/proxy.mov")

        try await AVProxyGenerator().makeProxy(from: source, to: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        let asset = AVURLAsset(url: destination)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(duration, StillImageVideoWriter.durationInSeconds, accuracy: 0.2)
        XCTAssertLessThanOrEqual(max(size.width, size.height), 1280)
    }
}
