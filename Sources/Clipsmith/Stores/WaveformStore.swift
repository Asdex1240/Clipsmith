import Foundation
import Observation

@MainActor
@Observable
final class WaveformStore {
    private(set) var peaksByURL: [URL: [Float]] = [:]
    @ObservationIgnored private var loading: Set<URL> = []
    @ObservationIgnored private let generator: WaveformGenerating

    init(generator: WaveformGenerating = AVWaveformGenerator()) {
        self.generator = generator
    }

    func load(_ url: URL) async {
        guard peaksByURL[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        peaksByURL[url] = await generator.peaks(for: url)
        loading.remove(url)
    }
}
