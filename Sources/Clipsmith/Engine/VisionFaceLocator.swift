import AVFoundation
import Vision

struct VisionFaceLocator: FaceLocating {
    private static let maximumSide: CGFloat = 640

    func faceSample(in url: URL, at times: [TimeInterval]) async -> FaceSample? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: Self.maximumSide, height: Self.maximumSide)
        var centers: [Double] = []
        var aspect: Double?
        for time in times {
            guard
                let image = try? await generator.image(
                    at: CMTime(seconds: time, preferredTimescale: 600)
                ).image
            else { continue }
            aspect = Double(image.width) / Double(image.height)
            if let center = Self.largestFaceCenter(in: image) { centers.append(center) }
        }
        guard let aspect else { return nil }
        return FaceSample(centers: centers, sourceAspect: aspect)
    }

    private static func largestFaceCenter(in image: CGImage) -> Double? {
        let request = VNDetectFaceRectanglesRequest()
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else {
            return nil
        }
        let largest = request.results?.max {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }
        return largest.map { Double($0.boundingBox.midX) }
    }
}
