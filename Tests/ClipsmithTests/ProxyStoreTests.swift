import XCTest
@testable import Clipsmith

private final class FakeProxyGenerator: ProxyGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var generated: [URL] = []
    var heavy: Set<URL> = []
    var failing: Set<URL> = []

    var generatedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return generated
    }

    func needsProxy(for url: URL) async -> Bool { heavy.contains(url) }

    func makeProxy(from url: URL, to destination: URL) async throws {
        lock.lock()
        generated.append(url)
        lock.unlock()
        if failing.contains(url) { throw ProxyError.exportFailed("boom") }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("proxy".utf8).write(to: destination)
    }
}

@MainActor
final class ProxyStoreTests: XCTestCase {
    private var directory: URL!
    private var generator: FakeProxyGenerator!
    private var defaults: UserDefaults!
    private let big = URL(fileURLWithPath: "/tmp/clipsmith-big.mp4")
    private let small = URL(fileURLWithPath: "/tmp/clipsmith-small.mp4")

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "proxy-tests-\(UUID().uuidString)")
        generator = FakeProxyGenerator()
        generator.heavy = [big]
        defaults = UserDefaults(suiteName: "proxy-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> ProxyStore {
        ProxyStore(generator: generator, directory: directory, defaults: defaults)
    }

    private func project(_ urls: [URL]) -> Project {
        var project = Project(name: "T")
        var start = 0.0
        for url in urls {
            var clip = TestClips.video(start: start, sourceEnd: 5)
            clip.sourceURL = url
            project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
            start += 5
        }
        return project
    }

    private func waitUntilIdle(_ store: ProxyStore) async {
        for _ in 0..<200 where store.isPreparing {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(store.isPreparing)
    }

    func testHeavyVideosAreSubstitutedAndLightOnesAreNot() async {
        let store = makeStore()
        let source = project([big, small])

        store.prepare(for: source)
        await waitUntilIdle(store)
        let preview = store.substituting(source)

        let urls = preview.track(withRole: .main)!.clips.compactMap(\.sourceURL)
        XCTAssertEqual(urls[0], store.cachedURL(for: big))
        XCTAssertEqual(urls[1], small)
        XCTAssertEqual(source.track(withRole: .main)!.clips[0].sourceURL, big)
    }

    func testTheSameFileUsedTwiceIsOnlyGeneratedOnce() async {
        let store = makeStore()

        store.prepare(for: project([big, big]))
        await waitUntilIdle(store)

        XCTAssertEqual(generator.generatedURLs, [big])
    }

    func testAnExistingProxyOnDiskIsReused() async throws {
        let first = makeStore()
        first.prepare(for: project([big]))
        await waitUntilIdle(first)
        generator.heavy = []

        let second = makeStore()
        second.prepare(for: project([big]))
        await waitUntilIdle(second)

        XCTAssertEqual(generator.generatedURLs.count, 1)
        XCTAssertNotNil(second.proxyURLs[big])
    }

    func testFailedProxiesAreNotRetried() async {
        generator.failing = [big]
        let store = makeStore()
        let source = project([big])

        store.prepare(for: source)
        await waitUntilIdle(store)
        store.prepare(for: source)
        await waitUntilIdle(store)

        XCTAssertEqual(generator.generatedURLs.count, 1)
        XCTAssertEqual(store.substituting(source), source)
    }

    func testDisablingUsesTheOriginalsAndEnablingPreparesAgain() async {
        let store = makeStore()
        let source = project([big])
        store.setEnabled(false)

        store.prepare(for: source)
        XCTAssertFalse(store.isPreparing)
        XCTAssertTrue(generator.generatedURLs.isEmpty)
        XCTAssertEqual(store.substituting(source), source)

        store.setEnabled(true)
        await waitUntilIdle(store)
        XCTAssertNotEqual(store.substituting(source), source)
    }

    func testTheChoiceIsRemembered() {
        makeStore().setEnabled(false)

        XCTAssertFalse(makeStore().isEnabled)
    }

    func testOnlyVideoClipsAreSubstituted() async {
        let store = makeStore()
        var source = project([big])
        source.addClip(
            TestClips.audio(start: 0, duration: 5), toTrack: source.track(withRole: .audio)!.id)

        store.prepare(for: source)
        await waitUntilIdle(store)
        let preview = store.substituting(source)

        XCTAssertEqual(
            preview.track(withRole: .audio)!.clips, source.track(withRole: .audio)!.clips)
    }

    func testTheOwnerIsNotifiedWhenAProxyIsReady() async {
        let store = makeStore()
        var notifications = 0
        store.onChange = { notifications += 1 }

        store.prepare(for: project([big]))
        await waitUntilIdle(store)

        XCTAssertEqual(notifications, 1)
    }
}

@MainActor
final class CacheControllerTests: XCTestCase {
    private var root: URL!
    private var generator: ControllerFakeGenerator!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cache-controller-\(UUID().uuidString)")
        generator = ControllerFakeGenerator()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func project(_ url: URL) -> Project {
        var project = Project(name: "T")
        var clip = TestClips.video(start: 0, sourceEnd: 5)
        clip.sourceURL = url
        project.addClip(clip, toTrack: project.track(withRole: .main)!.id)
        return project
    }

    func testClearingForgetsProxiesDeletesFilesAndRebuilds() async throws {
        let big = URL(fileURLWithPath: "/tmp/clipsmith-cache-big.mp4")
        let proxyDirectory = root.appendingPathComponent("proxies")
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "cc-\(UUID().uuidString)"))
        let proxies = ProxyStore(generator: generator, directory: proxyDirectory, defaults: defaults)
        let denoise = DenoiseStore(cache: DenoisedAudioCache(directory: root.appendingPathComponent("clean")))
        var cleared = 0
        let controller = CacheController(
            cleaner: CacheCleaner(directories: [proxyDirectory]), proxies: proxies, denoise: denoise,
            onCleared: { cleared += 1 })
        proxies.prepare(for: project(big))
        for _ in 0..<200 where proxies.isPreparing { try await Task.sleep(for: .milliseconds(10)) }
        await controller.refresh()
        XCTAssertGreaterThan(controller.sizeInBytes, 0)
        XCTAssertFalse(proxies.proxyURLs.isEmpty)

        await controller.clear()

        XCTAssertTrue(proxies.proxyURLs.isEmpty)
        XCTAssertEqual(controller.sizeInBytes, 0)
        XCTAssertGreaterThan(controller.lastFreedBytes ?? 0, 0)
        XCTAssertEqual(cleared, 1)
        XCTAssertFalse(controller.isWorking)
        XCTAssertFalse(proxies.isPreparing)
    }

    func testAfterResettingProxiesCanBeMadeAgain() async {
        let big = URL(fileURLWithPath: "/tmp/clipsmith-cache-big.mp4")
        let defaults = UserDefaults(suiteName: "cc-\(UUID().uuidString)")!
        let proxies = ProxyStore(
            generator: generator, directory: root.appendingPathComponent("p"), defaults: defaults)

        proxies.prepare(for: project(big))
        for _ in 0..<200 where proxies.isPreparing { try? await Task.sleep(for: .milliseconds(10)) }
        await proxies.reset()
        try? FileManager.default.removeItem(at: root.appendingPathComponent("p"))
        proxies.prepare(for: project(big))
        for _ in 0..<200 where proxies.isPreparing { try? await Task.sleep(for: .milliseconds(10)) }

        XCTAssertNotNil(proxies.proxyURLs[big])
        XCTAssertEqual(generator.count, 2)
    }
}

private final class ControllerFakeGenerator: ProxyGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var generated = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return generated
    }

    func needsProxy(for url: URL) async -> Bool { true }

    func makeProxy(from url: URL, to destination: URL) async throws {
        lock.lock()
        generated += 1
        lock.unlock()
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 1000).write(to: destination)
    }
}
