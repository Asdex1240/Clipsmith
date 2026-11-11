import Foundation
import Observation

@MainActor
@Observable
final class CacheController {
    private(set) var sizeInBytes: Int64 = 0
    private(set) var isWorking = false
    private(set) var lastFreedBytes: Int64?

    @ObservationIgnored private let cleaner: CacheCleaner
    @ObservationIgnored private let proxies: ProxyStore
    @ObservationIgnored private let denoise: DenoiseStore
    @ObservationIgnored private let onCleared: () -> Void

    init(
        cleaner: CacheCleaner = .standard, proxies: ProxyStore, denoise: DenoiseStore,
        onCleared: @escaping () -> Void
    ) {
        self.cleaner = cleaner
        self.proxies = proxies
        self.denoise = denoise
        self.onCleared = onCleared
    }

    func refresh() async {
        let cleaner = cleaner
        sizeInBytes = await Task.detached { cleaner.totalSize() }.value
    }

    func clear() async {
        guard !isWorking else { return }
        isWorking = true
        await proxies.reset()
        await denoise.reset()
        let cleaner = cleaner
        let report = await Task.detached { cleaner.clearAll() }.value
        lastFreedBytes = report.removedBytes
        onCleared()
        await refresh()
        isWorking = false
    }
}
