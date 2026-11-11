import AVFoundation

struct AVProxyGenerator: ProxyGenerating {
    static let thresholdInPixels: CGFloat = 1920

    func needsProxy(for url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
            let size = try? await track.load(.naturalSize),
            let transform = try? await track.load(.preferredTransform)
        else { return false }
        let oriented = CGRect(origin: .zero, size: size).applying(transform)
        return max(abs(oriented.width), abs(oriented.height)) > Self.thresholdInPixels
    }

    func makeProxy(from url: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: url)
        guard
            let session = AVAssetExportSession(
                asset: asset, presetName: AVAssetExportPreset1280x720)
        else { throw ProxyError.cannotCreateSession }
        let partial = destination.appendingPathExtension("partial")
        FileManager.default.discardItemIgnoringFailure(at: partial)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        session.outputURL = partial
        session.outputFileType = .mov
        await session.exportUntilFinishedOrCancelled()
        try Task.checkCancellation()
        guard session.status == .completed else {
            FileManager.default.discardItemIgnoringFailure(at: partial)
            throw ProxyError.exportFailed(session.error?.localizedDescription ?? "")
        }
        FileManager.default.discardItemIgnoringFailure(at: destination)
        try FileManager.default.moveItem(at: partial, to: destination)
    }
}
