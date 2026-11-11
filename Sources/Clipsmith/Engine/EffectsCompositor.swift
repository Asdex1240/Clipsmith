import AVFoundation
import CoreImage

final class EffectsCompositor: NSObject, AVVideoCompositing {
    private static let pixelFormat = kCVPixelFormatType_32BGRA

    private let context = CIContext(options: [
        .workingColorSpace: NSNull(), .outputColorSpace: NSNull(),
    ])
    private let queue = DispatchQueue(label: "Clipsmith.EffectsCompositor")

    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [Self.pixelFormat]]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: [Self.pixelFormat]]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [self] in render(request) }
    }

    func cancelAllPendingVideoCompositionRequests() {}

    private func render(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? EffectsInstruction,
            let output = request.renderContext.newPixelBuffer()
        else {
            request.finish(with: NSError(domain: "Clipsmith.EffectsCompositor", code: 1))
            return
        }
        let size = request.renderContext.size
        let bounds = CGRect(origin: .zero, size: size)
        let time = request.compositionTime.seconds
        var canvas = CIImage(color: .black).cropped(to: bounds)
        for layer in instruction.layers.reversed() {
            guard let frame = request.sourceFrame(byTrackID: layer.trackID),
                let image = LayerImage.make(
                    for: layer, frame: frame, at: time, renderHeight: size.height)
            else { continue }
            canvas = image.composited(over: canvas)
        }
        for sprite in instruction.texts
        where time >= sprite.startInSeconds && time < sprite.endInSeconds {
            if let image = LayerImage.make(sprite, at: time, renderHeight: size.height) {
                canvas = image.composited(over: canvas)
            }
        }
        context.render(canvas, to: output, bounds: bounds, colorSpace: nil)
        request.finish(withComposedVideoFrame: output)
    }
}
