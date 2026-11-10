import AVFoundation

enum ExportError: Error, LocalizedError {
    case nothingToExport
    case cannotCreateSession
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToExport: return localized("error.export.empty")
        case .cannotCreateSession: return localized("error.export.session")
        case .cancelled: return localized("error.export.cancelled")
        case .failed(let reason): return String(format: localized("error.export.failed"), reason)
        }
    }
}

protocol Exporting {
    func export(
        _ project: Project,
        with settings: ExportSettings,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws
}

struct ProjectExporter: Exporting {
    private static let progressPollInterval: Duration = .milliseconds(100)

    var builder: CompositionBuilding = CompositionBuilder()

    func export(
        _ project: Project,
        with settings: ExportSettings,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard project.durationInSeconds > 0 else { throw ExportError.nothingToExport }
        let built = try await builder.build(
            from: project,
            renderSize: settings.resolution.renderSize(for: project.canvas),
            framesPerSecond: Int32(settings.framesPerSecond)
        )
        try Task.checkCancellation()
        try await run(built, codec: settings.codec, to: destination, progress: progress)
    }

    private func run(
        _ built: BuiltComposition,
        codec: VideoCodec,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(asset: built.composition, presetName: codec.exportPresetName) else {
            throw ExportError.cannotCreateSession
        }
        try? FileManager.default.removeItem(at: destination)
        session.outputURL = destination
        session.outputFileType = .mp4
        built.attachTextOverlayForExport()
        session.videoComposition = built.videoComposition
        session.audioMix = built.audioMix
        session.shouldOptimizeForNetworkUse = true

        nonisolated(unsafe) let sharedSession = session
        let poller = Task {
            while !Task.isCancelled {
                progress(Double(sharedSession.progress))
                try? await Task.sleep(for: Self.progressPollInterval)
            }
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                session.exportAsynchronously { continuation.resume() }
            }
        } onCancel: {
            sharedSession.cancelExport()
        }
        poller.cancel()
        try finish(session, destination: destination)
        progress(1)
    }

    private func finish(_ session: AVAssetExportSession, destination: URL) throws {
        switch session.status {
        case .completed:
            return
        case .cancelled:
            try? FileManager.default.removeItem(at: destination)
            throw ExportError.cancelled
        default:
            try? FileManager.default.removeItem(at: destination)
            throw ExportError.failed(session.error?.localizedDescription ?? "")
        }
    }
}

private extension VideoCodec {
    var exportPresetName: String {
        switch self {
        case .h264: return AVAssetExportPresetHighestQuality
        case .hevc: return AVAssetExportPresetHEVCHighestQuality
        }
    }
}
