import AVFoundation
import XCTest
@testable import Clipsmith

final class ClipSpeedTests: XCTestCase {
    func testDoubleSpeedHalvesTheTimelineDuration() {
        var clip = TestClips.video(start: 2, sourceEnd: 10)
        clip.speed = 2

        XCTAssertEqual(clip.durationInSeconds, 5)
        XCTAssertEqual(clip.endInSeconds, 7)
        XCTAssertEqual(clip.sourceSpanInSeconds, 10)
    }

    func testSettingSpeedIsClampedToTheSupportedRange() {
        let clip = TestClips.video(start: 0)

        XCTAssertEqual(clip.settingSpeed(100).speed, Clip.speedRange.upperBound)
        XCTAssertEqual(clip.settingSpeed(0.01).speed, Clip.speedRange.lowerBound)
    }

    func testSlowingDownDoesNotRunIntoTheNextClip() {
        var project = Project(name: "T")
        let main = project.track(withRole: .main)!.id
        let first = TestClips.video(start: 0, sourceEnd: 10)
        project.addClip(first, toTrack: main)
        project.addClip(TestClips.video(start: 12, sourceEnd: 5), toTrack: main)

        project.setSpeed(of: first.id, to: 0.25)

        let updated = project.clip(withID: first.id)!
        XCTAssertLessThanOrEqual(updated.endInSeconds, 12 + 1e-9)
        XCTAssertEqual(updated.speed, 10.0 / 12.0, accuracy: 1e-9)
    }

    func testImagesAndTextIgnoreSpeed() {
        let text = Clip(text: TextLayer(content: "Hi"), startInSeconds: 0, durationInSeconds: 3)

        XCTAssertEqual(text.settingSpeed(2).speed, 1)
    }

    func testSplitKeepsSourceContinuityAtAnySpeed() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 10)
        clip.speed = 2

        let halves = try XCTUnwrap(clip.split(at: 2))

        XCTAssertEqual(halves.left.sourceEndInSeconds, 4, accuracy: 1e-9)
        XCTAssertEqual(halves.right.sourceStartInSeconds, 4, accuracy: 1e-9)
        XCTAssertEqual(halves.left.durationInSeconds, 2, accuracy: 1e-9)
        XCTAssertEqual(halves.right.durationInSeconds, 3, accuracy: 1e-9)
        XCTAssertEqual(halves.right.speed, 2)
    }

    func testTrimmingMovesTheSourceByTheScaledAmount() {
        var clip = TestClips.video(start: 0, sourceEnd: 10)
        clip.speed = 2

        let trimmed = clip.trimmedLeading(to: 1, notBefore: 0)

        XCTAssertEqual(trimmed.sourceStartInSeconds, 2, accuracy: 1e-9)
        XCTAssertEqual(trimmed.durationInSeconds, 4, accuracy: 1e-9)
        XCTAssertEqual(
            clip.trimmedTrailing(to: 3, notAfter: .infinity).sourceEndInSeconds, 6, accuracy: 1e-9)
    }

    func testSpeedSurvivesSavingAndOldFilesDefaultToNormalSpeed() throws {
        var clip = TestClips.video(start: 0)
        clip.speed = 1.5
        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))
        XCTAssertEqual(decoded.speed, 1.5)

        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(clip)) as? [String: Any])
        json.removeValue(forKey: "speed")
        let legacy = try JSONDecoder().decode(
            Clip.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.speed, 1)
    }

    func testSpeedPresetsAreSnappedWhenDraggingNearThem() {
        XCTAssertEqual(SpeedInspector.snapped(1.98), 2)
        XCTAssertEqual(SpeedInspector.snapped(1.3), 1.3)
    }

    func testCompositionPlaysAnAudioClipAtItsSpeed() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("tone.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100 * 6))
        buffer.frameLength = 44_100 * 6
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        var project = Project(name: "T")
        var clip = Clip(
            sourceURL: url, mediaKind: .audio, startInSeconds: 1,
            sourceStartInSeconds: 0, sourceEndInSeconds: 6, sourceDurationInSeconds: 6
        )
        clip.speed = 2
        project.addClip(clip, toTrack: project.track(withRole: .audio)!.id)

        let built = try await CompositionBuilder().build(from: project)

        XCTAssertEqual(built.durationInSeconds, 4, accuracy: 0.05)
    }
}
