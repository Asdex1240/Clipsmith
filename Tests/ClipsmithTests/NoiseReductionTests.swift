import AVFoundation
import XCTest
@testable import Clipsmith

private final class FakeNoiseProcessor: NoiseReductionProcessing, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [URL] = []
    var failing = false
    var silentFile = false

    var processedSources: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func process(source: URL, level: NoiseReductionLevel, destination: URL) async throws {
        lock.lock()
        calls.append(source)
        lock.unlock()
        if silentFile { throw NoiseReductionError.noAudio }
        if failing { throw NoiseReductionError.readFailed("boom") }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: destination)
    }
}

final class NoiseReductionModelTests: XCTestCase {
    func testTheChoiceSurvivesEncodingButTheOverrideIsNeverSaved() throws {
        var clip = TestClips.video(start: 0)
        clip.noiseReduction = .strong
        clip.audioOverrideURL = URL(fileURLWithPath: "/tmp/cleaned.caf")

        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(Clip.self, from: data)

        XCTAssertEqual(decoded.noiseReduction, .strong)
        XCTAssertNil(decoded.audioOverrideURL)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("cleaned.caf"))
    }

    func testOldProjectsHaveNoNoiseReduction() throws {
        let data = try JSONEncoder().encode(TestClips.video(start: 0))

        XCTAssertNil(try JSONDecoder().decode(Clip.self, from: data).noiseReduction)
    }

    @MainActor
    func testStoreSetsAndClearsTheLevelAsUndoableSteps() {
        let clip = TestClips.video(start: 0)
        var project = Project(name: "T")
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        let store = ProjectStore(project: project)

        store.setNoiseReduction(of: clip.id, to: .medium)
        XCTAssertEqual(store.project.clip(withID: clip.id)?.noiseReduction, .medium)
        store.setNoiseReduction(of: clip.id, to: nil)
        XCTAssertNil(store.project.clip(withID: clip.id)?.noiseReduction)
        store.undo()
        XCTAssertEqual(store.project.clip(withID: clip.id)?.noiseReduction, .medium)
    }
}

@MainActor
final class DenoisedAudioCacheTests: XCTestCase {
    private var directory: URL!
    private var processor: FakeNoiseProcessor!
    private let source = URL(fileURLWithPath: "/tmp/clipsmith-noisy.mp4")

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "denoise-tests-\(UUID().uuidString)")
        processor = FakeNoiseProcessor()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func cache() -> DenoisedAudioCache {
        DenoisedAudioCache(directory: directory, processor: processor)
    }

    private func project(level: NoiseReductionLevel? = .medium, clips: Int = 1) -> Project {
        var project = Project(name: "T")
        for index in 0..<clips {
            var clip = TestClips.video(start: Double(index) * 5, sourceEnd: 5)
            clip.sourceURL = source
            clip.noiseReduction = level
            project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        }
        return project
    }

    private func waitUntilIdle(_ store: DenoiseStore) async {
        for _ in 0..<200 where store.isPreparing {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(store.isPreparing)
    }

    func testEachLevelHasItsOwnFile() {
        XCTAssertNotEqual(
            cache().url(for: source, level: .light), cache().url(for: source, level: .strong))
    }

    func testOnlyClipsWithNoiseReductionAreRequestedAndOncePerFile() {
        XCTAssertEqual(cache().requests(in: project(clips: 3)).count, 1)
        XCTAssertTrue(cache().requests(in: project(level: nil)).isEmpty)
    }

    func testTheOverrideIsOnlySetOnceTheFileExists() async throws {
        let cache = cache()
        let original = project()
        XCTAssertNil(cache.applying(to: original).tracks[2].clips[0].audioOverrideURL)

        let prepared = try await cache.ensure(original)

        let clip = try XCTUnwrap(prepared.track(withRole: .main)?.clips.first)
        XCTAssertEqual(clip.audioOverrideURL, cache.url(for: source, level: .medium))
        XCTAssertNil(original.track(withRole: .main)?.clips.first?.audioOverrideURL)
    }

    func testEnsureDoesNotProcessTwice() async throws {
        let cache = cache()

        _ = try await cache.ensure(project(clips: 2))
        _ = try await cache.ensure(project(clips: 2))

        XCTAssertEqual(processor.processedSources.count, 1)
    }

    func testAFileWithoutAudioIsSkippedAndFailuresAreReported() async throws {
        processor.silentFile = true
        let skipped = try await cache().ensure(project())
        XCTAssertNil(skipped.track(withRole: .main)?.clips.first?.audioOverrideURL)

        processor.silentFile = false
        processor.failing = true
        do {
            _ = try await cache().ensure(project())
            XCTFail("Expected the failure to be thrown")
        } catch {
            XCTAssertEqual(error as? NoiseReductionError, .readFailed("boom"))
        }
    }

    func testStoreProcessesInTheBackgroundAndNotifiesOnce() async {
        let store = DenoiseStore(cache: cache())
        var notifications = 0
        store.onChange = { notifications += 1 }
        let source = project(clips: 2)

        store.prepare(for: source)
        store.prepare(for: source)
        await waitUntilIdle(store)

        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(processor.processedSources.count, 1)
        XCTAssertNotNil(
            store.applying(source).track(withRole: .main)?.clips.first?.audioOverrideURL)
    }

    func testStoreReportsAFailureAndDoesNotRetry() async {
        processor.failing = true
        let store = DenoiseStore(cache: cache())
        let source = project()

        store.prepare(for: source)
        await waitUntilIdle(store)
        store.prepare(for: source)
        await waitUntilIdle(store)

        XCTAssertEqual(processor.processedSources.count, 1)
        XCTAssertNotNil(store.lastFailure)
    }
}

final class AVNoiseReducerTests: XCTestCase {
    private var directory: URL!
    private let rate = 16_000.0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nr-av-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeNoisyFile(channels: Int, seconds: Double) throws -> URL {
        let url = directory.appendingPathComponent("noisy-\(channels).wav")
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: rate,
                channels: AVAudioChannelCount(channels), interleaved: false))
        let frames = Int(rate * seconds)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        for channel in 0..<channels {
            let data = try XCTUnwrap(buffer.floatChannelData)[channel]
            for index in 0..<frames {
                let time = Double(index) / rate
                let tone = Int(time / 0.7) % 2 == 0 ? Float(0.3 * sin(2 * .pi * 1000 * time)) : 0
                data[index] = tone + Float.random(in: -0.05...0.05)
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    private func quietRMS(of url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let data = try XCTUnwrap(buffer.floatChannelData)[0]
        var total: Float = 0
        var count = 0
        for index in Int(rate * 3)..<Int(buffer.frameLength) {
            let time = Double(index) / rate
            guard Int(time / 0.7) % 2 == 1 else { continue }
            total += data[index] * data[index]
            count += 1
        }
        return sqrt(total / Float(count))
    }

    func testProducesACleanerFileOfTheSameLength() async throws {
        let source = try makeNoisyFile(channels: 1, seconds: 8)
        let destination = directory.appendingPathComponent("out/clean.caf")

        try await AVNoiseReducer().process(source: source, level: .medium, destination: destination)

        let before = try quietRMS(of: source)
        let after = try quietRMS(of: destination)
        XCTAssertLessThan(after, before * 0.5)
        let original = try AVAudioFile(forReading: source)
        let cleaned = try AVAudioFile(forReading: destination)
        XCTAssertEqual(cleaned.length, original.length)
        XCTAssertEqual(cleaned.fileFormat.sampleRate, rate)
    }

    func testKeepsTheChannelCount() async throws {
        let source = try makeNoisyFile(channels: 2, seconds: 4)
        let destination = directory.appendingPathComponent("stereo.caf")

        try await AVNoiseReducer().process(source: source, level: .light, destination: destination)

        XCTAssertEqual(try AVAudioFile(forReading: destination).fileFormat.channelCount, 2)
    }

    func testAFileWithoutAnAudioTrackIsRejected() async throws {
        let png = directory.appendingPathComponent("nothing.txt")
        try Data("x".utf8).write(to: png)

        do {
            try await AVNoiseReducer().process(
                source: png, level: .light, destination: directory.appendingPathComponent("x.caf"))
            XCTFail("Expected an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
