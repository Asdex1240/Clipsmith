import Foundation
import Observation

@MainActor
@Observable
final class DenoiseStore {
    private(set) var pendingCount = 0
    private(set) var lastFailure: String?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var failed: Set<String> = []
    @ObservationIgnored private var queued: Set<String> = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let cache: DenoisedAudioCache

    init(cache: DenoisedAudioCache? = nil) {
        self.cache = cache ?? DenoisedAudioCache()
    }

    var isPreparing: Bool { pendingCount > 0 }

    func applying(_ project: Project) -> Project {
        cache.applying(to: project)
    }

    func prepare(for project: Project) {
        let fresh = cache.missing(in: project).filter {
            let key = Self.key($0.source, $0.level)
            return !failed.contains(key) && !queued.contains(key)
        }
        guard !fresh.isEmpty else { return }
        for request in fresh { queued.insert(Self.key(request.source, request.level)) }
        pendingCount += fresh.count
        lastFailure = nil
        let previous = task
        task = Task {
            await previous?.value
            for request in fresh { await run(request) }
        }
    }

    func cancel() {
        task?.cancel()
    }

    func reset() async {
        task?.cancel()
        await task?.value
        task = nil
        failed = []
        queued = []
        pendingCount = 0
        lastFailure = nil
    }

    private func run(_ request: (source: URL, level: NoiseReductionLevel)) async {
        let key = Self.key(request.source, request.level)
        defer {
            queued.remove(key)
            pendingCount -= 1
        }
        guard !Task.isCancelled else { return }
        do {
            try await cache.generate(request.source, level: request.level)
            onChange?()
        } catch NoiseReductionError.noAudio {
            failed.insert(key)
        } catch is CancellationError {
            return
        } catch {
            failed.insert(key)
            lastFailure = error.localizedDescription
        }
    }

    private static func key(_ source: URL, _ level: NoiseReductionLevel) -> String {
        "\(source.path)|\(level.rawValue)"
    }
}
