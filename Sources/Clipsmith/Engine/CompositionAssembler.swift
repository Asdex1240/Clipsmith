import AVFoundation
import ImageIO
import OSLog

final class CompositionAssembler {
    private static let scaleToleranceInSeconds: TimeInterval = 1e-6
    private static let heldFrameInSeconds: TimeInterval = 1.0 / 30

    private struct VideoSource {
        let asset: AVURLAsset
        let assetTrack: AVAssetTrack
        let startInSeconds: TimeInterval
        let isStill: Bool
        let trackID: Track.ID
    }

    private let composition = AVMutableComposition()
    private let renderSize: CGSize
    private let framesPerSecond: Int32
    private let stillImages: StillImageVideoMaking
    private let logger = Logger(subsystem: "Clipsmith", category: "composition")
    private var videoTracks: [Track.ID: AVMutableCompositionTrack] = [:]
    private var audioTracks: [Track.ID: AVMutableCompositionTrack] = [:]
    private var placements: [Clip.ID: RenderLayer] = [:]
    private var videoSources: [Clip.ID: VideoSource] = [:]
    private var transitionTracks: [Track.ID: AVMutableCompositionTrack] = [:]
    private var tailPlacements: [Clip.ID: RenderLayer] = [:]
    private var skippedClipIDs: [Clip.ID] = []
    private var textClips: [Clip] = []
    private var visualFrames: [Clip.ID: CGRect] = [:]
    private var volumeSteps: [Track.ID: [VolumeStep]] = [:]

    init(renderSize: CGSize, framesPerSecond: Int32, stillImages: StillImageVideoMaking) {
        self.renderSize = renderSize
        self.framesPerSecond = framesPerSecond
        self.stillImages = stillImages
    }

    func add(_ clip: Clip, in track: Track) async {
        do {
            try await insert(clip, in: track)
        } catch {
            skippedClipIDs.append(clip.id)
            logger.error("Skipped clip \(clip.displayName): \(error.localizedDescription)")
        }
    }

    func finish(segments: [PlannedSegment]) -> BuiltComposition {
        let covered = CompositionPlanner.clamp(segments, toDuration: composition.duration.seconds)
        insertTails(for: covered.flatMap(\.transitions))
        return BuiltComposition(
            composition: composition,
            videoComposition: makeVideoComposition(covering: covered),
            audioMix: makeAudioMix(),
            textOverlay: TextOverlay(clips: textClips, renderSize: renderSize),
            skippedClipIDs: skippedClipIDs,
            visualFrames: visualFrames
        )
    }

    private func insert(_ clip: Clip, in track: Track) async throws {
        switch track.role {
        case .main:
            try await insertVideo(clip, in: track.id)
            if !clip.isAudioDetached { await insertEmbeddedAudio(of: clip, in: track.id) }
        case .broll:
            try await insertVideo(clip, in: track.id)
        case .audio:
            try await insertAudio(clip, in: track.id)
        case .text:
            textClips.append(clip)
        }
    }

    private func insertVideo(_ clip: Clip, in trackID: Track.ID) async throws {
        let source = try await resolveVideoSource(for: clip)
        guard let assetTrack = try await source.asset.loadTracks(withMediaType: .video).first else {
            throw CompositionError.missingTrack(source.asset.url)
        }
        let target = try videoTrack(for: trackID)
        var insertedDuration = clip.sourceSpanInSeconds
        if source.isStill { insertedDuration = StillImageVideoWriter.durationInSeconds }
        let insertedRange = CMTimeRange(
            start: source.startInSeconds.cmTime, duration: insertedDuration.cmTime)
        try target.insertTimeRange(insertedRange, of: assetTrack, at: clip.startInSeconds.cmTime)
        scaleInsertedFootage(of: clip, in: target, insertedDuration: insertedDuration)
        let (naturalSize, preferredTransform) = try await assetTrack.load(
            .naturalSize, .preferredTransform)
        videoSources[clip.id] = VideoSource(
            asset: source.asset, assetTrack: assetTrack, startInSeconds: source.startInSeconds,
            isStill: source.isStill, trackID: trackID
        )
        placements[clip.id] = RenderLayer(
            trackID: target.trackID, clip: clip, naturalSize: naturalSize,
            preferredTransform: preferredTransform, renderSize: renderSize
        )
        visualFrames[clip.id] = contentFrame(
            of: clip, naturalSize: naturalSize, preferredTransform: preferredTransform)
    }

    private func scaleInsertedFootage(
        of clip: Clip, in target: AVMutableCompositionTrack, insertedDuration: TimeInterval
    ) {
        guard abs(insertedDuration - clip.durationInSeconds) > Self.scaleToleranceInSeconds else {
            return
        }
        let insertedAt = CMTimeRange(
            start: clip.startInSeconds.cmTime, duration: insertedDuration.cmTime)
        target.scaleTimeRange(insertedAt, toDuration: clip.durationInSeconds.cmTime)
    }

    private func contentFrame(
        of clip: Clip, naturalSize: CGSize, preferredTransform: CGAffineTransform
    ) -> CGRect {
        var size = naturalSize
        var transform = preferredTransform
        if clip.mediaKind == .image, let url = clip.sourceURL,
            let pixels = Self.pixelSize(ofImageAt: url)
        {
            size = pixels
            transform = .identity
        }
        let fitted = FitTransform.make(
            naturalSize: size, preferredTransform: transform, renderSize: renderSize,
            mode: clip.fitMode)
        return CGRect(origin: .zero, size: size).applying(fitted)
    }

    private static func pixelSize(ofImageAt url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        return CGSize(width: width, height: height)
    }

    private func insertAudio(_ clip: Clip, in trackID: Track.ID) async throws {
        guard try await insertAudioTrack(of: clip, in: trackID) else {
            throw CompositionError.missingTrack(try sourceURL(of: clip))
        }
    }

    private func insertEmbeddedAudio(of clip: Clip, in trackID: Track.ID) async {
        do {
            _ = try await insertAudioTrack(of: clip, in: trackID)
        } catch {
            logger.error("Audio of \(clip.displayName) not added: \(error.localizedDescription)")
        }
    }

    private func insertAudioTrack(of clip: Clip, in trackID: Track.ID) async throws -> Bool {
        guard clip.mediaKind != .image else { return false }
        let asset = AVURLAsset(url: try clip.audioOverrideURL ?? sourceURL(of: clip))
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            return false
        }
        let range = CMTimeRange(
            start: clip.sourceStartInSeconds.cmTime, duration: clip.sourceSpanInSeconds.cmTime)
        let target = try audioTrack(for: trackID)
        try target.insertTimeRange(range, of: assetTrack, at: clip.startInSeconds.cmTime)
        if abs(clip.sourceSpanInSeconds - clip.durationInSeconds) > Self.scaleToleranceInSeconds {
            let insertedAt = CMTimeRange(
                start: clip.startInSeconds.cmTime, duration: clip.sourceSpanInSeconds.cmTime)
            target.scaleTimeRange(insertedAt, toDuration: clip.durationInSeconds.cmTime)
        }
        volumeSteps[trackID, default: []].append(contentsOf: VolumeAutomation.steps(for: clip))
        return true
    }

    private func resolveVideoSource(
        for clip: Clip
    ) async throws -> (asset: AVURLAsset, startInSeconds: TimeInterval, isStill: Bool) {
        let url = try sourceURL(of: clip)
        guard clip.mediaKind == .image else {
            return (AVURLAsset(url: url), clip.sourceStartInSeconds, false)
        }
        let stillURL = try await stillImages.makeVideo(
            from: url, size: renderSize, mode: clip.fitMode)
        return (AVURLAsset(url: stillURL), 0, true)
    }

    private func sourceURL(of clip: Clip) throws -> URL {
        guard let url = clip.sourceURL else { throw CompositionError.missingSource }
        return url
    }

    private func makeAudioMix() -> AVAudioMix? {
        let parameters = audioTracks.compactMap {
            trackID, track -> AVMutableAudioMixInputParameters? in
            guard let steps = volumeSteps[trackID], !steps.isEmpty else { return nil }
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
        let range = CMTimeRange(
            start: step.startInSeconds.cmTime, duration: step.durationInSeconds.cmTime)
        parameters.setVolumeRamp(
            fromStartVolume: step.startVolume, toEndVolume: step.endVolume, timeRange: range)
    }

    private func videoTrack(for trackID: Track.ID) throws -> AVMutableCompositionTrack {
        if let existing = videoTracks[trackID] { return existing }
        guard
            let created = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CompositionError.cannotCreateTrack
        }
        videoTracks[trackID] = created
        return created
    }

    private func audioTrack(for trackID: Track.ID) throws -> AVMutableCompositionTrack {
        if let existing = audioTracks[trackID] { return existing }
        guard
            let created = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CompositionError.cannotCreateTrack
        }
        audioTracks[trackID] = created
        return created
    }

    private func makeVideoComposition(
        covering segments: [PlannedSegment]
    ) -> AVMutableVideoComposition? {
        guard !videoTracks.isEmpty, !segments.isEmpty else { return nil }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: framesPerSecond)
        let usesEffects = placements.values.contains { $0.clip.hasLookEffects }
        if usesEffects { videoComposition.customVideoCompositorClass = EffectsCompositor.self }
        videoComposition.instructions = segments.enumerated().map { index, segment in
            let isLast = index == segments.count - 1
            var end = segment.endInSeconds.cmTime
            if isLast { end = composition.duration }
            if usesEffects { return effectsInstruction(for: segment, endingAt: end) }
            return instruction(for: segment, endingAt: end)
        }
        return videoComposition
    }

    private func effectsInstruction(
        for segment: PlannedSegment, endingAt end: CMTime
    ) -> EffectsInstruction {
        EffectsInstruction(
            timeRange: CMTimeRange(start: segment.startInSeconds.cmTime, end: end),
            layers: segment.clipIDsTopFirst.flatMap { layers(for: $0, in: segment) }
        )
    }

    private func instruction(
        for segment: PlannedSegment, endingAt end: CMTime
    ) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: segment.startInSeconds.cmTime, end: end)
        instruction.backgroundColor = CGColor(gray: 0, alpha: 1)
        instruction.layerInstructions = segment.clipIDsTopFirst.flatMap {
            layers(for: $0, in: segment)
        }
        .compactMap { layerInstruction(for: $0, in: segment) }
        return instruction
    }

    private func layers(for clipID: Clip.ID, in segment: PlannedSegment) -> [RenderLayer] {
        guard let incoming = placements[clipID] else { return [] }
        guard let transition = segment.transitions.first(where: { $0.incomingClipID == clipID }),
            let tail = tailPlacements[clipID]
        else { return [incoming] }
        return [
            tail.blending(LayerBlend(transition: transition, isOutgoing: true)),
            incoming.blending(LayerBlend(transition: transition, isOutgoing: false)),
        ]
    }

    private func layerInstruction(
        for layer: RenderLayer, in segment: PlannedSegment
    ) -> AVVideoCompositionLayerInstruction? {
        guard let track = composition.track(withTrackID: layer.trackID) else { return nil }
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        guard layer.needsAnimation else {
            instruction.setTransform(layer.transform(at: layer.clip.startInSeconds), at: .zero)
            return instruction
        }
        let points = LayerAnimation.samplePoints(
            for: layer.clip, from: segment.startInSeconds, to: segment.endInSeconds,
            extraAnchors: layer.blend?.breakpoints ?? []
        )
        for (from, to) in zip(points, points.dropFirst()) {
            let range = CMTimeRange(start: from.cmTime, end: to.cmTime)
            instruction.setTransformRamp(
                fromStart: layer.transform(at: from), toEnd: layer.transform(at: to),
                timeRange: range)
            instruction.setOpacityRamp(
                fromStartOpacity: Float(layer.opacity(at: from)),
                toEndOpacity: Float(layer.opacity(at: to)), timeRange: range
            )
        }
        return instruction
    }

    // MARK: Transitions

    private func insertTails(for transitions: [PlannedTransition]) {
        var done = Set<Clip.ID>()
        for transition in transitions where done.insert(transition.incomingClipID).inserted {
            do {
                try insertTail(for: transition)
            } catch {
                logger.error("Transition skipped: \(error.localizedDescription)")
            }
        }
    }

    private func insertTail(for transition: PlannedTransition) throws {
        guard let placement = placements[transition.outgoingClipID],
            let source = videoSources[transition.outgoingClipID]
        else { return }
        let outgoing = placement.clip
        let target = try transitionTrack(for: source.trackID)
        let duration = transition.windowEnd - transition.windowStart
        var availableSource = 0.0
        if !source.isStill {
            availableSource = (outgoing.sourceDurationInSeconds ?? 0) - outgoing.sourceEndInSeconds
        }
        if availableSource >= duration * outgoing.speed - Self.scaleToleranceInSeconds {
            try insertContinuingFootage(of: outgoing, from: source, into: target, at: transition)
        } else {
            guard try insertHeldFrame(of: outgoing, from: source, into: target, at: transition)
            else { return }
        }
        tailPlacements[transition.incomingClipID] = RenderLayer(
            trackID: target.trackID, clip: outgoing, naturalSize: placement.naturalSize,
            preferredTransform: placement.preferredTransform, renderSize: renderSize
        )
    }

    private func insertContinuingFootage(
        of outgoing: Clip, from source: VideoSource, into target: AVMutableCompositionTrack,
        at transition: PlannedTransition
    ) throws {
        let duration = transition.windowEnd - transition.windowStart
        let start = transition.windowStart.cmTime
        let range = CMTimeRange(
            start: outgoing.sourceEndInSeconds.cmTime, duration: (duration * outgoing.speed).cmTime)
        try target.insertTimeRange(range, of: source.assetTrack, at: start)
        guard outgoing.speed != 1 else { return }
        target.scaleTimeRange(
            CMTimeRange(start: start, duration: range.duration), toDuration: duration.cmTime)
    }

    private func insertHeldFrame(
        of outgoing: Clip, from source: VideoSource, into target: AVMutableCompositionTrack,
        at transition: PlannedTransition
    ) throws -> Bool {
        var held = source.startInSeconds
        var heldDuration = StillImageVideoWriter.durationInSeconds
        if !source.isStill {
            held = max(outgoing.sourceEndInSeconds - Self.heldFrameInSeconds, source.startInSeconds)
            heldDuration = outgoing.sourceEndInSeconds - held
        }
        guard heldDuration > 0 else { return false }
        let start = transition.windowStart.cmTime
        let range = CMTimeRange(start: held.cmTime, duration: heldDuration.cmTime)
        try target.insertTimeRange(range, of: source.assetTrack, at: start)
        let duration = transition.windowEnd - transition.windowStart
        target.scaleTimeRange(
            CMTimeRange(start: start, duration: range.duration), toDuration: duration.cmTime)
        return true
    }

    private func transitionTrack(for trackID: Track.ID) throws -> AVMutableCompositionTrack {
        if let existing = transitionTracks[trackID] { return existing }
        guard
            let created = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CompositionError.cannotCreateTrack
        }
        transitionTracks[trackID] = created
        return created
    }
}
