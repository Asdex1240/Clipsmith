import AVFoundation
import CoreImage

enum LayerImage {
    static func make(
        for layer: RenderLayer, frame: CVPixelBuffer, at time: TimeInterval, renderHeight: CGFloat
    ) -> CIImage? {
        let sourceHeight = CGFloat(CVPixelBufferGetHeight(frame))
        var image = CIImage(cvPixelBuffer: frame)
        image = cropped(image, to: layer, sourceHeight: sourceHeight)
        image = colorCorrected(image, with: layer.clip.color)
        let flipSource = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: sourceHeight)
        let flipCanvas = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: renderHeight)
        let source = image
        image = source.transformed(
            by: flipSource.concatenating(layer.transform(at: time)).concatenating(flipCanvas))
        if layer.clip.fitMode == .blur {
            let background = BlurredBackground.make(
                from: source,
                fillTransform: flipSource.concatenating(layer.backgroundTransform(at: time))
                    .concatenating(flipCanvas),
                canvas: CGRect(origin: .zero, size: layer.renderSize))
            image = image.composited(over: background)
        }
        let opacity = layer.opacity(at: time)
        guard opacity > 0 else { return nil }
        return faded(image, to: opacity)
    }

    private static func faded(_ image: CIImage, to opacity: Double) -> CIImage {
        guard opacity < 1 else { return image }
        return image.applyingFilter(
            "CIColorMatrix",
            parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)])
    }

    static func make(_ sprite: TextSprite, at time: TimeInterval, renderHeight: CGFloat) -> CIImage?
    {
        let state = sprite.animation.state(
            atClipTime: time - sprite.startInSeconds,
            clipDuration: sprite.endInSeconds - sprite.startInSeconds
        )
        guard state.opacity > 0 else { return nil }
        let size = CGSize(width: sprite.image.width, height: sprite.image.height)
        let placement = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(scaleX: state.scale, y: state.scale))
            .concatenating(CGAffineTransform(rotationAngle: sprite.rotationInRadians))
            .concatenating(
                CGAffineTransform(
                    translationX: sprite.center.x, y: sprite.center.y - state.offsetY * renderHeight
                ))
        let image = CIImage(cgImage: sprite.image).transformed(by: placement)
        return faded(image, to: state.opacity)
    }

    private static func cropped(
        _ image: CIImage, to layer: RenderLayer, sourceHeight: CGFloat
    ) -> CIImage {
        let crop = layer.clip.crop
        guard !crop.isNone else { return image }
        let oriented = CGRect(origin: .zero, size: layer.naturalSize).applying(
            layer.preferredTransform)
        let visible = crop.visible(in: oriented)
        let source = visible.applying(layer.preferredTransform.inverted())
        let rect = CGRect(
            x: source.minX, y: sourceHeight - source.maxY, width: source.width,
            height: source.height)
        return image.cropped(to: rect)
    }

    private static let neutralKelvin = 6500.0
    private static let kelvinSpan = 3000.0

    static func colorCorrected(_ image: CIImage, with color: ColorAdjustments) -> CIImage {
        guard !color.isIdentity else { return image }
        var result = image
        if color.brightness != 0 || color.contrast != 1 || color.saturation != 1 {
            result = result.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputBrightnessKey: color.brightness,
                    kCIInputContrastKey: color.contrast,
                    kCIInputSaturationKey: color.saturation,
                ])
        }
        if color.temperature != 0 {
            result = result.applyingFilter(
                "CITemperatureAndTint",
                parameters: [
                    "inputNeutral": CIVector(
                        x: neutralKelvin + color.temperature * kelvinSpan, y: 0),
                    "inputTargetNeutral": CIVector(x: neutralKelvin, y: 0),
                ])
        }
        return result
    }
}
