import AVFoundation

struct AVFilmstripGenerator: FilmstripGenerating {
    static let frameHeightInPixels: CGFloat = 96

    func filmstrip(for url: URL) async -> Filmstrip? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0 else {
            return nil
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: Self.frameHeightInPixels * 4, height: Self.frameHeightInPixels)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        let times = Filmstrip.frameTimes(forDuration: duration).map { $0.cmTime }
        var frames: [CGImage] = []
        for await result in generator.images(for: times) {
            if Task.isCancelled { return nil }
            if let image = try? result.image { frames.append(image) }
        }
        guard !frames.isEmpty else { return nil }
        return Filmstrip(frames: frames, durationInSeconds: duration)
    }
}
