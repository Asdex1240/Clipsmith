import Foundation
import Observation

@MainActor
@Observable
final class FilmstripStore {
    private(set) var stripsByURL: [URL: Filmstrip] = [:]
    @ObservationIgnored private var loading: Set<URL> = []
    @ObservationIgnored private let generator: FilmstripGenerating

    init(generator: FilmstripGenerating = MediaFilmstripGenerator()) {
        self.generator = generator
    }

    func load(_ url: URL) async {
        guard stripsByURL[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        stripsByURL[url] = await generator.filmstrip(for: url)
        loading.remove(url)
    }
}
