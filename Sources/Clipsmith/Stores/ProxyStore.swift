import CryptoKit
import Foundation
import Observation

@MainActor
@Observable
final class ProxyStore {
    static let enabledKey = "fastPreview"

    private(set) var proxyURLs: [URL: URL] = [:]
    private(set) var pendingCount = 0
    private(set) var isEnabled: Bool
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var failed: Set<URL> = []
    @ObservationIgnored private var queued: Set<URL> = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let generator: ProxyGenerating
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults

    init(
        generator: ProxyGenerating = AVProxyGenerator(),
        directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipsmith-proxies"),
        defaults: UserDefaults = .standard
    ) {
        self.generator = generator
        self.directory = directory
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    var isPreparing: Bool { pendingCount > 0 }

    func setEnabled(_ value: Bool) {
        guard value != isEnabled else { return }
        isEnabled = value
        defaults.set(value, forKey: Self.enabledKey)
        if value { prepare(for: lastProject) }
        onChange?()
    }

    @ObservationIgnored private var lastProject = Project(name: "")

    func substituting(_ project: Project) -> Project {
        guard isEnabled, !proxyURLs.isEmpty else { return project }
        var copy = project
        for trackIndex in copy.tracks.indices {
            for clipIndex in copy.tracks[trackIndex].clips.indices {
                let clip = copy.tracks[trackIndex].clips[clipIndex]
                guard clip.mediaKind == .video, let url = clip.sourceURL,
                    let proxy = proxyURLs[url]
                else { continue }
                copy.tracks[trackIndex].clips[clipIndex].sourceURL = proxy
            }
        }
        return copy
    }

    func prepare(for project: Project) {
        lastProject = project
        guard isEnabled else { return }
        let urls = Set(
            project.tracks.flatMap(\.clips).filter { $0.mediaKind == .video }.compactMap(
                \.sourceURL))
        let fresh = urls.filter {
            proxyURLs[$0] == nil && !failed.contains($0) && !queued.contains($0)
        }
        guard !fresh.isEmpty else { return }
        queued.formUnion(fresh)
        pendingCount += fresh.count
        let ordered = fresh.sorted { $0.path < $1.path }
        let previous = task
        task = Task {
            await previous?.value
            for url in ordered { await prepareOne(url) }
        }
    }

    func cancel() {
        task?.cancel()
    }

    func reset() async {
        task?.cancel()
        await task?.value
        task = nil
        proxyURLs = [:]
        failed = []
        queued = []
        pendingCount = 0
    }

    private func prepareOne(_ url: URL) async {
        defer {
            queued.remove(url)
            pendingCount -= 1
        }
        guard !Task.isCancelled, isEnabled else { return }
        let destination = cachedURL(for: url)
        if FileManager.default.fileExists(atPath: destination.path) {
            CacheCleaner.touch(destination)
            register(url, proxy: destination)
            return
        }
        guard await generator.needsProxy(for: url) else {
            failed.insert(url)
            return
        }
        do {
            try await generator.makeProxy(from: url, to: destination)
            register(url, proxy: destination)
        } catch {
            if !(error is CancellationError) { failed.insert(url) }
        }
    }

    private func register(_ url: URL, proxy: URL) {
        proxyURLs[url] = proxy
        onChange?()
    }

    func cachedURL(for url: URL) -> URL {
        let values = try? url.resourceValues(forKeys: [
            .contentModificationDateKey, .fileSizeKey,
        ])
        let key =
            "\(url.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)"
        let digest = SHA256.hash(data: Data(key.utf8)).prefix(12).map { String(format: "%02x", $0) }
            .joined()
        return directory.appendingPathComponent("\(digest).mov")
    }
}
