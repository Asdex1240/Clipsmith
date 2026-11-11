import AVFoundation

struct AVNoiseReducer: NoiseReductionProcessing {
    func process(source: URL, level: NoiseReductionLevel, destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NoiseReductionError.noAudio
        }
        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first,
            let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee
        else { throw NoiseReductionError.noAudio }
        let sampleRate = basic.mSampleRate
        let channels = Int(basic.mChannelsPerFrame)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let partial = destination.deletingPathExtension().appendingPathExtension("partial.caf")
        try? FileManager.default.removeItem(at: partial)
        do {
            try write(
                track: track, asset: asset, level: level, sampleRate: sampleRate,
                channels: channels, to: partial)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: partial, to: destination)
    }

    private func write(
        track: AVAssetTrack, asset: AVURLAsset, level: NoiseReductionLevel, sampleRate: Double,
        channels: Int, to url: URL
    ) throws {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
            ])
        reader.add(output)
        guard reader.startReading(),
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                channels: AVAudioChannelCount(channels), interleaved: false)
        else { throw NoiseReductionError.readFailed(reader.error?.localizedDescription ?? "") }
        let file = try AVAudioFile(
            forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32,
            interleaved: false)
        let denoisers = (0..<channels).map { _ in
            SpectralDenoiser(sampleRate: sampleRate, level: level)
        }
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let samples = Self.channelSamples(of: buffer, channels: channels)
            try append(denoisers.enumerated().map { $1.process(samples[$0]) }, to: file, format: format)
        }
        guard reader.status == .completed else {
            throw NoiseReductionError.readFailed(reader.error?.localizedDescription ?? "")
        }
        try append(denoisers.map { $0.finish() }, to: file, format: format)
    }

    private func append(
        _ channelData: [[Float]], to file: AVAudioFile, format: AVAudioFormat
    ) throws {
        guard let frames = channelData.first?.count, frames > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
            let destination = buffer.floatChannelData
        else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        for (channel, values) in channelData.enumerated() {
            values.withUnsafeBufferPointer {
                destination[channel].update(from: $0.baseAddress!, count: frames)
            }
        }
        try file.write(from: buffer)
    }

    private static func channelSamples(of buffer: CMSampleBuffer, channels: Int) -> [[Float]] {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else {
            return [[Float]](repeating: [], count: channels)
        }
        let length = CMBlockBufferGetDataLength(block)
        var interleaved = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
        interleaved.withUnsafeMutableBytes {
            _ = CMBlockBufferCopyDataBytes(
                block, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
        }
        let frames = interleaved.count / channels
        return (0..<channels).map { channel in
            (0..<frames).map { interleaved[$0 * channels + channel] }
        }
    }
}
