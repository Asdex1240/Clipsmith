import Foundation

protocol FilmstripGenerating: Sendable {
    func filmstrip(for url: URL) async -> Filmstrip?
}
