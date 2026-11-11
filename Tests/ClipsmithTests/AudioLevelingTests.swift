import XCTest
@testable import Clipsmith

final class LoudnessNormalizerTests: XCTestCase {
    private let rate = WaveformSpec.peaksPerSecond

    private func peaks(_ level: Float, seconds: Double) -> [Float] {
        [Float](repeating: level, count: Int(seconds * rate))
    }

    func testQuietClipIsBoosted() throws {
        let volume = try XCTUnwrap(
            LoudnessNormalizer.volume(peaks: peaks(0.1, seconds: 10), from: 0, to: 10))

        XCTAssertEqual(volume, 2, accuracy: 1e-6)
    }

    func testLoudClipIsLowered() throws {
        let volume = try XCTUnwrap(
            LoudnessNormalizer.volume(peaks: peaks(0.7, seconds: 10), from: 0, to: 10))

        XCTAssertEqual(volume, 0.5, accuracy: 1e-6)
    }

    func testGainNeverPushesThePeakOverTheCeiling() throws {
        var data = peaks(0.2, seconds: 10)
        data[100] = 0.9

        let volume = try XCTUnwrap(LoudnessNormalizer.volume(peaks: data, from: 0, to: 10))

        XCTAssertLessThanOrEqual(Float(volume) * 0.9, LoudnessNormalizer.peakCeiling + 1e-5)
    }

    func testSilenceOrTooLittleAudioGivesNothing() {
        XCTAssertNil(LoudnessNormalizer.volume(peaks: peaks(0, seconds: 10), from: 0, to: 10))
        XCTAssertNil(LoudnessNormalizer.volume(peaks: peaks(0.5, seconds: 0.5), from: 0, to: 0.5))
    }

    func testOnlyTheClipRangeIsMeasured() throws {
        let data = peaks(0.7, seconds: 10) + peaks(0.1, seconds: 10)

        let volume = try XCTUnwrap(LoudnessNormalizer.volume(peaks: data, from: 10, to: 20))

        XCTAssertEqual(volume, 2, accuracy: 1e-6)
    }
}

final class SpeechActivityTests: XCTestCase {
    private let rate = WaveformSpec.peaksPerSecond

    private func peaks(_ parts: [(Double, Float)]) -> [Float] {
        parts.flatMap { [Float](repeating: $0.1, count: Int($0.0 * rate)) }
    }

    func testFindsSpeechAndMergesShortPauses() {
        let data = peaks([(1, 0), (2, 0.5), (0.3, 0), (2, 0.5), (3, 0), (1, 0.5), (1, 0)])

        let ranges = SpeechActivity.ranges(peaks: data, from: 0, to: 10.3)

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].lowerBound, 1, accuracy: 0.02)
        XCTAssertEqual(ranges[0].upperBound, 5.3, accuracy: 0.02)
        XCTAssertEqual(ranges[1].lowerBound, 8.3, accuracy: 0.02)
    }

    func testIgnoresBlipsShorterThanTheMinimum() {
        let data = peaks([(1, 0), (0.1, 0.8), (1, 0)])

        XCTAssertTrue(SpeechActivity.ranges(peaks: data, from: 0, to: 2.1).isEmpty)
    }

    func testPlannerCombinesSeveralVoiceClipsOnTheTimeline() {
        let first = TestClips.video(start: 0, sourceEnd: 5)
        let second = TestClips.video(start: 10, sourceEnd: 5)
        let speech = peaks([(5, 0.5)])

        let ranges = DuckingPlanner.timelineRanges(voices: [(first, speech), (second, speech)])

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[1].lowerBound, 10, accuracy: 0.02)
    }
}

final class ClipDuckingTests: XCTestCase {
    private func music(sourceEnd: TimeInterval = 30) -> Clip {
        TestClips.audio(start: 0, duration: sourceEnd)
    }

    func testDuckingAddsADipAroundEachSpeechRange() {
        var clip = music()
        clip.ducking = ClipDucking(
            level: 0.2, ranges: [ClipDucking.Range(start: 10, end: 14)])

        let steps = VolumeAutomation.steps(for: clip)

        let down = steps.first { $0.endVolume == 0.2 }
        let up = steps.first { $0.startVolume == 0.2 }
        XCTAssertEqual(down?.startInSeconds ?? 0, 10 - ClipDucking.attackInSeconds, accuracy: 1e-9)
        XCTAssertEqual(up?.startInSeconds ?? 0, 14, accuracy: 1e-9)
        XCTAssertEqual(up?.endVolume, 1)
    }

    func testCloseRangesShareASingleDip() {
        var clip = music()
        clip.ducking = ClipDucking(
            level: 0.2,
            ranges: [
                ClipDucking.Range(start: 10, end: 12), ClipDucking.Range(start: 12.3, end: 14),
            ])

        let steps = VolumeAutomation.steps(for: clip)

        XCTAssertEqual(steps.filter { $0.endVolume == 0.2 }.count, 1)
    }

    func testDipsStayInsideTheFades() {
        var clip = music()
        clip.fadeInDurationInSeconds = 3
        clip.fadeOutDurationInSeconds = 3
        clip.ducking = ClipDucking(
            level: 0.2, ranges: [ClipDucking.Range(start: 0, end: 30)])

        let steps = VolumeAutomation.steps(for: clip)

        let down = steps.first { $0.endVolume == 0.2 }!
        let up = steps.first { $0.startVolume == 0.2 }!
        XCTAssertGreaterThanOrEqual(down.startInSeconds, 3 - 1e-9)
        XCTAssertLessThanOrEqual(up.startInSeconds + up.durationInSeconds, 27 + 1e-9)
    }

    func testNoDuckingLeavesTheStepsUntouched() {
        XCTAssertEqual(VolumeAutomation.steps(for: music()).count, 1)
    }

    func testDuckingSurvivesEncodingAndSplitting() throws {
        var clip = music()
        clip.ducking = ClipDucking(level: 0.3, ranges: [ClipDucking.Range(start: 20, end: 25)])

        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))
        let halves = try XCTUnwrap(clip.split(at: 10))

        XCTAssertEqual(decoded.ducking, clip.ducking)
        XCTAssertEqual(halves.right.duckingRangesOnTimeline(), [20..<25])
    }

    @MainActor
    func testStoreDucksUnderTimelineRangesAndCanUndo() {
        let voice = TestClips.video(start: 0, sourceEnd: 30)
        let bed = music()
        var project = Project(name: "T")
        project.addClip(voice, toTrack: project.track(withRole: .main)!.id)
        project.addClip(bed, toTrack: project.track(withRole: .audio)!.id)
        let store = ProjectStore(project: project)

        let count = store.applyDucking(to: bed.id, under: [5..<8, 12..<15], level: 0.3)

        XCTAssertEqual(count, 2)
        XCTAssertEqual(store.project.clip(withID: bed.id)?.ducking?.level, 0.3)
        store.setDuckLevel(of: bed.id, to: 5)
        XCTAssertEqual(
            store.project.clip(withID: bed.id)?.ducking?.level, ClipDucking.levelRange.upperBound)
        store.clearDucking(of: bed.id)
        XCTAssertNil(store.project.clip(withID: bed.id)?.ducking)
        store.undo()
        XCTAssertNotNil(store.project.clip(withID: bed.id)?.ducking)
    }

    @MainActor
    func testStoreNormalizesTheClipVolume() {
        let clip = TestClips.video(start: 0, sourceEnd: 10)
        var project = Project(name: "T")
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        let store = ProjectStore(project: project)
        let peaks = [Float](repeating: 0.7, count: Int(10 * WaveformSpec.peaksPerSecond))

        let volume = store.normalizeVolume(of: clip.id, peaks: peaks)

        XCTAssertEqual(volume ?? 0, 0.5, accuracy: 1e-6)
        XCTAssertEqual(store.project.clip(withID: clip.id)?.volume ?? 0, 0.5, accuracy: 1e-6)
    }
}
