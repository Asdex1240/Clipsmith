import AVFoundation
import OSLog

enum CompositionError: Error {
    case missingTrack(URL)
    case cannotCreateTrack
}

final class CompositionAssembler {
    static let framesPerSecond: Int32 = 30

    private struct Placement {
        let trackID: CMPersistentTrackID
        let transform: CGAffineTransform
    }

    private let composition = AVMutableComposition()
    private let renderSize: CGSize
    private let stillImages: StillImageVideoMaking
    private let logger = Logger(subsystem: "Clipsmith", category: "composition")
    private var videoTracks: [Track.Role: AVMutableCompositionTrack] = [:]
    private var audioTracks: [Track.Role: AVMutableCompositionTrack] = [:]
    private var placements: [Clip.ID: Placement] = [:]
    private var skippedClipIDs: [Clip.ID] = []

    init(renderSize: CGSize, stillImages: StillImageVideoMaking) {
        self.renderSize = renderSize
        self.stillImages = stillImages
    }

    func add(_ clip: Clip, role: Track.Role) async {
        do {
            try await insert(clip, role: role)
        } catch {
            skippedClipIDs.append(clip.id)
            logger.error("Skipped clip \(clip.sourceURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func finish(segments: [PlannedSegment]) -> BuiltComposition {
        let covered = CompositionPlanner.clamp(segments, toDuration: composition.duration.seconds)
        return BuiltComposition(
            composition: composition,
            videoComposition: makeVideoComposition(covering: covered),
            skippedClipIDs: skippedClipIDs
        )
    }

    private func insert(_ clip: Clip, role: Track.Role) async throws {
        switch role {
        case .main:
            try await insertVideo(clip, role: role)
            await insertEmbeddedAudio(of: clip, role: role)
        case .broll:
            try await insertVideo(clip, role: role)
        case .audio:
            try await insertAudio(clip, role: role)
        case .text:
            break
        }
    }

    private func insertVideo(_ clip: Clip, role: Track.Role) async throws {
        let source = try await resolveVideoSource(for: clip)
        guard let assetTrack = try await source.asset.loadTracks(withMediaType: .video).first else {
            throw CompositionError.missingTrack(clip.sourceURL)
        }
        let target = try videoTrack(for: role)
        let insertedDuration = source.isStill ? StillImageVideoWriter.durationInSeconds : clip.durationInSeconds
        let insertedRange = CMTimeRange(start: source.startInSeconds.cmTime, duration: insertedDuration.cmTime)
        try target.insertTimeRange(insertedRange, of: assetTrack, at: clip.startInSeconds.cmTime)
        if source.isStill {
            let stillRange = CMTimeRange(start: clip.startInSeconds.cmTime, duration: insertedDuration.cmTime)
            target.scaleTimeRange(stillRange, toDuration: clip.durationInSeconds.cmTime)
        }
        let (naturalSize, preferredTransform) = try await assetTrack.load(.naturalSize, .preferredTransform)
        placements[clip.id] = Placement(
            trackID: target.trackID,
            transform: FitTransform.make(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                renderSize: renderSize
            )
        )
    }

    private func insertAudio(_ clip: Clip, role: Track.Role) async throws {
        guard try await insertAudioTrack(of: clip, role: role) else {
            throw CompositionError.missingTrack(clip.sourceURL)
        }
    }

    private func insertEmbeddedAudio(of clip: Clip, role: Track.Role) async {
        do {
            _ = try await insertAudioTrack(of: clip, role: role)
        } catch {
            logger.error("Audio of \(clip.sourceURL.lastPathComponent) not added: \(error.localizedDescription)")
        }
    }

    private func insertAudioTrack(of clip: Clip, role: Track.Role) async throws -> Bool {
        guard clip.mediaKind != .image else { return false }
        let asset = AVURLAsset(url: clip.sourceURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else { return false }
        let range = CMTimeRange(start: clip.sourceStartInSeconds.cmTime, duration: clip.durationInSeconds.cmTime)
        try audioTrack(for: role).insertTimeRange(range, of: assetTrack, at: clip.startInSeconds.cmTime)
        return true
    }

    private func resolveVideoSource(for clip: Clip) async throws -> (asset: AVURLAsset, startInSeconds: TimeInterval, isStill: Bool) {
        guard clip.mediaKind == .image else {
            return (AVURLAsset(url: clip.sourceURL), clip.sourceStartInSeconds, false)
        }
        let stillURL = try await stillImages.makeVideo(from: clip.sourceURL, size: renderSize)
        return (AVURLAsset(url: stillURL), 0, true)
    }

    private func videoTrack(for role: Track.Role) throws -> AVMutableCompositionTrack {
        if let existing = videoTracks[role] { return existing }
        guard let created = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CompositionError.cannotCreateTrack
        }
        videoTracks[role] = created
        return created
    }

    private func audioTrack(for role: Track.Role) throws -> AVMutableCompositionTrack {
        if let existing = audioTracks[role] { return existing }
        guard let created = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CompositionError.cannotCreateTrack
        }
        audioTracks[role] = created
        return created
    }

    private func makeVideoComposition(covering segments: [PlannedSegment]) -> AVVideoComposition? {
        guard !videoTracks.isEmpty, !segments.isEmpty else { return nil }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: Self.framesPerSecond)
        videoComposition.instructions = segments.enumerated().map { index, segment in
            let isLast = index == segments.count - 1
            return instruction(for: segment, endingAt: isLast ? composition.duration : segment.endInSeconds.cmTime)
        }
        return videoComposition
    }

    private func instruction(for segment: PlannedSegment, endingAt end: CMTime) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: segment.startInSeconds.cmTime, end: end)
        instruction.backgroundColor = CGColor(gray: 0, alpha: 1)
        instruction.layerInstructions = segment.clipIDsTopFirst.compactMap(layerInstruction(for:))
        return instruction
    }

    private func layerInstruction(for clipID: Clip.ID) -> AVVideoCompositionLayerInstruction? {
        guard let placement = placements[clipID],
              let track = composition.track(withTrackID: placement.trackID) else { return nil }
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(placement.transform, at: .zero)
        return layer
    }
}
