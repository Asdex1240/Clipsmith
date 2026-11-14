import CoreImage
import Vision

final class VisionPersonMasker: PersonMasking, @unchecked Sendable {
    private let request = VNGeneratePersonSegmentationRequest()

    init(quality: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced) {
        request.qualityLevel = quality
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    func mask(for frame: CVPixelBuffer) -> CIImage? {
        let handler = VNImageRequestHandler(cvPixelBuffer: frame)
        guard (try? handler.perform([request])) != nil,
            let buffer = request.results?.first?.pixelBuffer
        else { return nil }
        let mask = CIImage(cvPixelBuffer: buffer)
        let frameExtent = CIImage(cvPixelBuffer: frame).extent
        guard mask.extent.width > 0, mask.extent.height > 0 else { return nil }
        return mask.transformed(
            by: CGAffineTransform(
                scaleX: frameExtent.width / mask.extent.width,
                y: frameExtent.height / mask.extent.height))
    }
}
