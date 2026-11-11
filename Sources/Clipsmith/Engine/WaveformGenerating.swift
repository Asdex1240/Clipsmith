import AVFoundation

protocol WaveformGenerating {
    func peaks(for url: URL) async -> [Float]
}
