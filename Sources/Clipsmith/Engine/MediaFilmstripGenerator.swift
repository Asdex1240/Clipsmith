import Foundation

struct MediaFilmstripGenerator: FilmstripGenerating {
    var video: FilmstripGenerating = AVFilmstripGenerator()
    var image: FilmstripGenerating = ImageFilmstripGenerator()

    func filmstrip(for url: URL) async -> Filmstrip? {
        switch MediaKind(url: url) {
        case .image: return await image.filmstrip(for: url)
        case .video, .audio, .text, nil: return await video.filmstrip(for: url)
        }
    }
}
