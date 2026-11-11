import AVFoundation
import CoreImage

final class EffectsInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let layers: [RenderLayer]
    let texts: [TextSprite]
    let enablePostProcessing = false
    let containsTweening = true
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let requiredSourceTrackIDs: [NSValue]?

    init(timeRange: CMTimeRange, layers: [RenderLayer], texts: [TextSprite] = []) {
        self.timeRange = timeRange
        self.layers = layers
        self.texts = texts
        var seen = Set<CMPersistentTrackID>()
        let newTrackIDs = layers.map(\.trackID).filter { seen.insert($0).inserted }
        requiredSourceTrackIDs = newTrackIDs.map { NSNumber(value: $0) }
    }
}

final class EffectsCompositor: NSObject, AVVideoCompositing {
    private static let pixelFormat = kCVPixelFormatType_32BGRA

    private let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    private let queue = DispatchQueue(label: "Clipsmith.EffectsCompositor")

    var sourcePixelBufferAttributes: [String: Any]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [Self.pixelFormat]]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [kCVPixelBufferPixelFormatTypeKey as String: [Self.pixelFormat]]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        nonisolated(unsafe) let pending = request
        queue.async { [self] in render(pending) }
    }

    func cancelAllPendingVideoCompositionRequests() {}

    private func render(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? EffectsInstruction,
              let output = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "Clipsmith.EffectsCompositor", code: 1))
            return
        }
        let size = request.renderContext.size
        let bounds = CGRect(origin: .zero, size: size)
        let time = request.compositionTime.seconds
        var canvas = CIImage(color: .black).cropped(to: bounds)
        for layer in instruction.layers.reversed() {
            guard let frame = request.sourceFrame(byTrackID: layer.trackID),
                  let image = LayerImage.make(for: layer, frame: frame, at: time, renderHeight: size.height) else { continue }
            canvas = image.composited(over: canvas)
        }
        for sprite in instruction.texts where time >= sprite.startInSeconds && time < sprite.endInSeconds {
            if let image = LayerImage.make(sprite, at: time, renderHeight: size.height) { canvas = image.composited(over: canvas) }
        }
        context.render(canvas, to: output, bounds: bounds, colorSpace: nil)
        request.finish(withComposedVideoFrame: output)
    }
}

enum LayerImage {
    static func make(for layer: RenderLayer, frame: CVPixelBuffer, at time: TimeInterval, renderHeight: CGFloat) -> CIImage? {
        let sourceHeight = CGFloat(CVPixelBufferGetHeight(frame))
        var image = CIImage(cvPixelBuffer: frame)
        image = cropped(image, to: layer, sourceHeight: sourceHeight)
        image = colorCorrected(image, with: layer.clip.color)
        let flipSource = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: sourceHeight)
        let flipCanvas = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: renderHeight)
        image = image.transformed(by: flipSource.concatenating(layer.transform(at: time)).concatenating(flipCanvas))
        let opacity = layer.opacity(at: time)
        guard opacity > 0 else { return nil }
        if opacity < 1 {
            image = image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)])
        }
        return image
    }

    static func make(_ sprite: TextSprite, at time: TimeInterval, renderHeight: CGFloat) -> CIImage? {
        let state = sprite.animation.state(
            atClipTime: time - sprite.startInSeconds, clipDuration: sprite.endInSeconds - sprite.startInSeconds
        )
        guard state.opacity > 0 else { return nil }
        let size = CGSize(width: sprite.image.width, height: sprite.image.height)
        let placement = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(scaleX: state.scale, y: state.scale))
            .concatenating(CGAffineTransform(rotationAngle: sprite.rotationInRadians))
            .concatenating(CGAffineTransform(translationX: sprite.center.x, y: sprite.center.y - state.offsetY * renderHeight))
        var image = CIImage(cgImage: sprite.image).transformed(by: placement)
        if state.opacity < 1 {
            image = image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: state.opacity)])
        }
        return image
    }

    private static func cropped(_ image: CIImage, to layer: RenderLayer, sourceHeight: CGFloat) -> CIImage {
        let crop = layer.clip.crop
        guard !crop.isNone else { return image }
        let oriented = CGRect(origin: .zero, size: layer.naturalSize).applying(layer.preferredTransform)
        let visible = crop.visible(in: oriented)
        let source = visible.applying(layer.preferredTransform.inverted())
        let rect = CGRect(x: source.minX, y: sourceHeight - source.maxY, width: source.width, height: source.height)
        return image.cropped(to: rect)
    }

    private static let neutralKelvin = 6500.0
    private static let kelvinSpan = 3000.0

    static func colorCorrected(_ image: CIImage, with color: ColorAdjustments) -> CIImage {
        guard !color.isIdentity else { return image }
        var result = image
        if color.brightness != 0 || color.contrast != 1 || color.saturation != 1 {
            result = result.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: color.brightness,
                kCIInputContrastKey: color.contrast,
                kCIInputSaturationKey: color.saturation,
            ])
        }
        if color.temperature != 0 {
            result = result.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: neutralKelvin + color.temperature * kelvinSpan, y: 0),
                "inputTargetNeutral": CIVector(x: neutralKelvin, y: 0),
            ])
        }
        return result
    }
}
