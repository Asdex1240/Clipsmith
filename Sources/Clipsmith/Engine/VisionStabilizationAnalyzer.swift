import AVFoundation
import Vision

struct VisionStabilizationAnalyzer: StabilizationAnalyzing {
    static let samplesPerSecond = 8.0
    static let maximumSide: CGFloat = 320

    func motion(
        in url: URL, sourceRange: ClosedRange<TimeInterval>,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [MotionSample]? {
        let times = Self.sampleTimes(in: sourceRange)
        guard times.count >= StabilizationPlanner.minimumSamples else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: Self.maximumSide, height: Self.maximumSide)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var samples: [MotionSample] = []
        var previous: CGImage?
        var done = 0
        for await result in generator.images(for: times.map { $0.cmTime }) {
            if Task.isCancelled { return nil }
            done += 1
            progress(Double(done) / Double(times.count))
            guard let image = try? result.image else { continue }
            defer { previous = image }
            guard let previous else {
                samples.append(
                    MotionSample(timeInSeconds: result.requestedTime.seconds, dx: 0, dy: 0))
                continue
            }
            guard let shift = Self.translation(from: previous, to: image) else { continue }
            samples.append(
                MotionSample(
                    timeInSeconds: result.requestedTime.seconds, dx: shift.width, dy: shift.height))
        }
        guard samples.count >= StabilizationPlanner.minimumSamples else { return nil }
        return samples
    }

    static func sampleTimes(in range: ClosedRange<TimeInterval>) -> [TimeInterval] {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return [] }
        let count = max(Int(span * samplesPerSecond), 1) + 1
        return (0..<count).map { range.lowerBound + Double($0) / samplesPerSecond }
            .filter { $0 <= range.upperBound }
    }

    private static func translation(from previous: CGImage, to current: CGImage) -> CGSize? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: previous)
        guard (try? VNImageRequestHandler(cgImage: current).perform([request])) != nil,
            let observation = request.results?.first as? VNImageTranslationAlignmentObservation
        else { return nil }
        let transform = observation.alignmentTransform
        return CGSize(
            width: transform.tx / CGFloat(current.width),
            height: -transform.ty / CGFloat(current.height))
    }
}
