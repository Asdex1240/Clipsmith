import AVFoundation

protocol WaveformGenerating {
    func peaks(for url: URL) async -> [Float]
}

struct AVWaveformGenerator: WaveformGenerating {
    private static let sampleRate = 8000

    func peaks(for url: URL) async -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return []
        }
        return await Task.detached(priority: .utility) { readPeaks(from: asset, track: track) }
            .value
    }

    private func readPeaks(from asset: AVURLAsset, track: AVAssetTrack) -> [Float] {
        guard let reader = try? AVAssetReader(asset: asset) else { return [] }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        guard reader.startReading() else { return [] }
        let samplesPerPeak = Int(Double(Self.sampleRate) / WaveformSpec.peaksPerSecond)
        var accumulator = PeakAccumulator(samplesPerPeak: samplesPerPeak)
        while let buffer = output.copyNextSampleBuffer() {
            accumulator.add(samples(in: buffer))
        }
        return accumulator.finish()
    }

    private var outputSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
        ]
    }

    private func samples(in buffer: CMSampleBuffer) -> [Int16] {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return [] }
        let length = CMBlockBufferGetDataLength(block)
        var samples = [Int16](repeating: 0, count: length / MemoryLayout<Int16>.size)
        samples.withUnsafeMutableBytes { pointer in
            guard let base = pointer.baseAddress else { return }
            CMBlockBufferCopyDataBytes(
                block, atOffset: 0, dataLength: pointer.count, destination: base)
        }
        return samples
    }
}
