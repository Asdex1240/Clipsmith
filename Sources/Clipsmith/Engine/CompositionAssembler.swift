import AVFoundation
import ImageIO
import OSLog

enum CompositionError: Error {
    case missingSource
    case missingTrack(URL)
    case cannotCreateTrack
}

final class CompositionAssembler {
    private struct Placement {
        let trackID: CMPersistentTrackID
        let naturalSize: CGSize
        let preferredTransform: CGAffineTransform
        let clip: Clip
    }

    private static let scaleToleranceInSeconds: TimeInterval = 1e-6

    private let composition = AVMutableComposition()
    private let renderSize: CGSize
    private let framesPerSecond: Int32
    private let stillImages: StillImageVideoMaking
    private let logger = Logger(subsystem: "Clipsmith", category: "composition")
    private var videoTracks: [Track.Role: AVMutableCompositionTrack] = [:]
    private var audioTracks: [Track.Role: AVMutableCompositionTrack] = [:]
    private var placements: [Clip.ID: Placement] = [:]
    private var skippedClipIDs: [Clip.ID] = []
    private var textClips: [Clip] = []
    private var visualFrames: [Clip.ID: CGRect] = [:]
    private var volumeSteps: [Track.Role: [VolumeStep]] = [:]

    init(renderSize: CGSize, framesPerSecond: Int32, stillImages: StillImageVideoMaking) {
        self.renderSize = renderSize
        self.framesPerSecond = framesPerSecond
        self.stillImages = stillImages
    }

    func add(_ clip: Clip, role: Track.Role) async {
        do {
            try await insert(clip, role: role)
        } catch {
            skippedClipIDs.append(clip.id)
            logger.error("Skipped clip \(clip.displayName): \(error.localizedDescription)")
        }
    }

    func finish(segments: [PlannedSegment]) -> BuiltComposition {
        let covered = CompositionPlanner.clamp(segments, toDuration: composition.duration.seconds)
        return BuiltComposition(
            composition: composition,
            videoComposition: makeVideoComposition(covering: covered),
            audioMix: makeAudioMix(),
            textOverlay: TextOverlay(clips: textClips, renderSize: renderSize),
            skippedClipIDs: skippedClipIDs,
            visualFrames: visualFrames
        )
    }

    private func insert(_ clip: Clip, role: Track.Role) async throws {
        switch role {
        case .main:
            try await insertVideo(clip, role: role)
            if !clip.isAudioDetached { await insertEmbeddedAudio(of: clip, role: role) }
        case .broll:
            try await insertVideo(clip, role: role)
        case .audio:
            try await insertAudio(clip, role: role)
        case .text:
            textClips.append(clip)
        }
    }

    private func insertVideo(_ clip: Clip, role: Track.Role) async throws {
        let source = try await resolveVideoSource(for: clip)
        guard let assetTrack = try await source.asset.loadTracks(withMediaType: .video).first else {
            throw CompositionError.missingTrack(source.asset.url)
        }
        let target = try videoTrack(for: role)
        let insertedDuration = source.isStill ? StillImageVideoWriter.durationInSeconds : clip.sourceSpanInSeconds
        let insertedRange = CMTimeRange(start: source.startInSeconds.cmTime, duration: insertedDuration.cmTime)
        try target.insertTimeRange(insertedRange, of: assetTrack, at: clip.startInSeconds.cmTime)
        if abs(insertedDuration - clip.durationInSeconds) > Self.scaleToleranceInSeconds {
            let insertedAt = CMTimeRange(start: clip.startInSeconds.cmTime, duration: insertedDuration.cmTime)
            target.scaleTimeRange(insertedAt, toDuration: clip.durationInSeconds.cmTime)
        }
        let (naturalSize, preferredTransform) = try await assetTrack.load(.naturalSize, .preferredTransform)
        placements[clip.id] = Placement(
            trackID: target.trackID, naturalSize: naturalSize, preferredTransform: preferredTransform, clip: clip
        )
        visualFrames[clip.id] = contentFrame(of: clip, naturalSize: naturalSize, preferredTransform: preferredTransform)
    }

    /// The area the picture itself covers (not the black bars), before the clip's offset.
    private func contentFrame(of clip: Clip, naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGRect {
        var size = naturalSize
        var transform = preferredTransform
        if clip.mediaKind == .image, let url = clip.sourceURL, let pixels = Self.pixelSize(ofImageAt: url) {
            size = pixels
            transform = .identity
        }
        let fitted = FitTransform.make(naturalSize: size, preferredTransform: transform, renderSize: renderSize, mode: clip.fitMode)
        return CGRect(origin: .zero, size: size).applying(fitted)
    }

    private static func pixelSize(ofImageAt url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else { return nil }
        return CGSize(width: width, height: height)
    }

    private func insertAudio(_ clip: Clip, role: Track.Role) async throws {
        guard try await insertAudioTrack(of: clip, role: role) else {
            throw CompositionError.missingTrack(try sourceURL(of: clip))
        }
    }

    private func insertEmbeddedAudio(of clip: Clip, role: Track.Role) async {
        do {
            _ = try await insertAudioTrack(of: clip, role: role)
        } catch {
            logger.error("Audio of \(clip.displayName) not added: \(error.localizedDescription)")
        }
    }

    private func insertAudioTrack(of clip: Clip, role: Track.Role) async throws -> Bool {
        guard clip.mediaKind != .image else { return false }
        let asset = AVURLAsset(url: try sourceURL(of: clip))
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else { return false }
        let range = CMTimeRange(start: clip.sourceStartInSeconds.cmTime, duration: clip.sourceSpanInSeconds.cmTime)
        let target = try audioTrack(for: role)
        try target.insertTimeRange(range, of: assetTrack, at: clip.startInSeconds.cmTime)
        if abs(clip.sourceSpanInSeconds - clip.durationInSeconds) > Self.scaleToleranceInSeconds {
            let insertedAt = CMTimeRange(start: clip.startInSeconds.cmTime, duration: clip.sourceSpanInSeconds.cmTime)
            target.scaleTimeRange(insertedAt, toDuration: clip.durationInSeconds.cmTime)
        }
        volumeSteps[role, default: []].append(contentsOf: VolumeAutomation.steps(for: clip))
        return true
    }

    private func resolveVideoSource(for clip: Clip) async throws -> (asset: AVURLAsset, startInSeconds: TimeInterval, isStill: Bool) {
        let url = try sourceURL(of: clip)
        guard clip.mediaKind == .image else {
            return (AVURLAsset(url: url), clip.sourceStartInSeconds, false)
        }
        let stillURL = try await stillImages.makeVideo(from: url, size: renderSize, mode: clip.fitMode)
        return (AVURLAsset(url: stillURL), 0, true)
    }

    private func sourceURL(of clip: Clip) throws -> URL {
        guard let url = clip.sourceURL else { throw CompositionError.missingSource }
        return url
    }

    private func makeAudioMix() -> AVAudioMix? {
        let parameters = audioTracks.compactMap { role, track -> AVMutableAudioMixInputParameters? in
            guard let steps = volumeSteps[role], !steps.isEmpty else { return nil }
            let inputParameters = AVMutableAudioMixInputParameters(track: track)
            for step in steps.sorted(by: { $0.startInSeconds < $1.startInSeconds }) {
                apply(step, to: inputParameters)
            }
            return inputParameters
        }
        guard !parameters.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = parameters
        return mix
    }

    private func apply(_ step: VolumeStep, to parameters: AVMutableAudioMixInputParameters) {
        guard step.durationInSeconds > 0 else {
            parameters.setVolume(step.startVolume, at: step.startInSeconds.cmTime)
            return
        }
        let range = CMTimeRange(start: step.startInSeconds.cmTime, duration: step.durationInSeconds.cmTime)
        parameters.setVolumeRamp(fromStartVolume: step.startVolume, toEndVolume: step.endVolume, timeRange: range)
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

    private func makeVideoComposition(covering segments: [PlannedSegment]) -> AVMutableVideoComposition? {
        guard !videoTracks.isEmpty, !segments.isEmpty else { return nil }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: framesPerSecond)
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
        instruction.layerInstructions = segment.clipIDsTopFirst.compactMap { layerInstruction(for: $0, in: segment) }
        return instruction
    }

    private func layerInstruction(for clipID: Clip.ID, in segment: PlannedSegment) -> AVVideoCompositionLayerInstruction? {
        guard let placement = placements[clipID],
              let track = composition.track(withTrackID: placement.trackID) else { return nil }
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let clip = placement.clip
        guard clip.needsAnimatedLayer else {
            layer.setTransform(transform(of: placement, at: clip.startInSeconds), at: .zero)
            return layer
        }
        let points = LayerAnimation.samplePoints(for: clip, from: segment.startInSeconds, to: segment.endInSeconds)
        for (from, to) in zip(points, points.dropFirst()) {
            let range = CMTimeRange(start: from.cmTime, end: to.cmTime)
            layer.setTransformRamp(
                fromStart: transform(of: placement, at: from), toEnd: transform(of: placement, at: to), timeRange: range
            )
            layer.setOpacityRamp(
                fromStartOpacity: opacity(of: clip, at: from), toEndOpacity: opacity(of: clip, at: to), timeRange: range
            )
        }
        return layer
    }

    private func transform(of placement: Placement, at time: TimeInterval) -> CGAffineTransform {
        let state = placement.clip.visualState(atClipTime: time - placement.clip.startInSeconds)
        return FitTransform.make(
            naturalSize: placement.naturalSize,
            preferredTransform: placement.preferredTransform,
            renderSize: renderSize,
            mode: placement.clip.fitMode,
            offset: CGPoint(x: state.offsetX * renderSize.width, y: state.offsetY * renderSize.height),
            scale: state.scale,
            rotationInDegrees: state.rotationInDegrees
        )
    }

    private func opacity(of clip: Clip, at time: TimeInterval) -> Float {
        Float(clip.visualState(atClipTime: time - clip.startInSeconds).opacity)
    }
}
