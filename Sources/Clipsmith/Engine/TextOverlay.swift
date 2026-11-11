import AVFoundation
import AppKit
import QuartzCore

struct TextOverlay: Equatable {
    var clips: [Clip]
    var renderSize: CGSize

    var isEmpty: Bool {
        clips.isEmpty
    }
}

struct TextSprite {
    let startInSeconds: TimeInterval
    let endInSeconds: TimeInterval
    let image: CGImage
    let center: CGPoint
    let rotationInRadians: Double
    let animation: TextAnimation
}

enum TextOverlayLayers {
    private static let maximumWidthFraction = 0.9
    private static let shadowOpacity = 0.6
    private static let shadowBlurFraction = 0.008
    private static let shadowPaddingFactor = 3.0
    private static let shadowBlurScale = 10.0
    private static let strokePercentScale = 100.0

    static func makeContainer(for overlay: TextOverlay) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: overlay.renderSize)
        for clip in overlay.clips {
            guard let text = clip.textLayer, let layer = makeLayer(for: clip, text: text, renderSize: overlay.renderSize) else {
                continue
            }
            layer.opacity = 0
            if text.animation.isNone {
                layer.add(visibilityAnimation(for: clip), forKey: "visibility")
            } else {
                for animation in animations(for: clip, text: text, renderHeight: overlay.renderSize.height) {
                    layer.add(animation.animation, forKey: animation.key)
                }
            }
            container.addSublayer(layer)
        }
        return container
    }

    static func makeStaticLayers(for overlay: TextOverlay) -> [(clip: Clip, layer: CALayer)] {
        overlay.clips.compactMap { clip in
            guard let text = clip.textLayer,
                  let layer = makeLayer(for: clip, text: text, renderSize: overlay.renderSize) else { return nil }
            return (clip, layer)
        }
    }

    static func makeSprites(for overlay: TextOverlay) -> [TextSprite] {
        let maximumWidth = overlay.renderSize.width * maximumWidthFraction
        let scale = min(overlay.renderSize.width, overlay.renderSize.height) / TextLayer.referenceShortSide
        return overlay.clips.compactMap { clip in
            guard let text = clip.textLayer, let image = renderImage(of: text, scale: scale, maximumWidth: maximumWidth) else {
                return nil
            }
            return TextSprite(
                startInSeconds: clip.startInSeconds,
                endInSeconds: clip.endInSeconds,
                image: image,
                center: CGPoint(x: text.positionX * overlay.renderSize.width, y: (1 - text.positionY) * overlay.renderSize.height),
                rotationInRadians: -text.rotationInDegrees * .pi / 180,
                animation: text.animation
            )
        }
    }

    static func attach(_ overlay: TextOverlay, to videoComposition: AVMutableVideoComposition) {
        let frame = CGRect(origin: .zero, size: overlay.renderSize)
        let videoLayer = CALayer()
        videoLayer.frame = frame
        let parent = CALayer()
        parent.frame = frame
        parent.addSublayer(videoLayer)
        parent.addSublayer(makeContainer(for: overlay))
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parent
        )
    }

    private static func makeLayer(for clip: Clip, text: TextLayer, renderSize: CGSize) -> CALayer? {
        let scale = min(renderSize.width, renderSize.height) / TextLayer.referenceShortSide
        guard let image = renderImage(of: text, scale: scale, maximumWidth: renderSize.width * maximumWidthFraction) else {
            return nil
        }
        let layer = CALayer()
        layer.contents = image
        layer.bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        layer.position = CGPoint(x: text.positionX * renderSize.width, y: (1 - text.positionY) * renderSize.height)
        layer.setAffineTransform(CGAffineTransform(rotationAngle: -text.rotationInDegrees * .pi / 180))
        return layer
    }

    static func textSize(of text: TextLayer, renderSize: CGSize) -> CGSize {
        let scale = min(renderSize.width, renderSize.height) / TextLayer.referenceShortSide
        let fontSize = text.fontSize * scale
        let font = NSFont(name: text.fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        let measured = NSAttributedString(string: text.content, attributes: [.font: font]).boundingRect(
            with: CGSize(width: renderSize.width * maximumWidthFraction, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
    }

    private static let backgroundPaddingFraction = 0.3
    private static let backgroundCornerFraction = 0.25
    private static let minimumPadding = 2.0

    private static func renderImage(of text: TextLayer, scale: Double, maximumWidth: CGFloat) -> CGImage? {
        let fontSize = text.fontSize * scale
        let font = NSFont(name: text.fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        let attributed = NSAttributedString(string: text.content, attributes: attributes(for: text, font: font, scale: scale))
        let measured = attributed.boundingRect(
            with: CGSize(width: maximumWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let boxPadding = text.backgroundColor == nil ? 0 : fontSize * backgroundPaddingFraction
        let padding = imagePadding(for: text, fontSize: fontSize, boxPadding: boxPadding)
        let width = Int(ceil(maximumWidth + 2 * padding))
        let height = Int(ceil(measured.height + 2 * padding))
        guard width > 0, height > 0, let context = makeContext(width: width, height: height) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        if let background = text.backgroundColor {
            let textWidth = min(ceil(measured.width), maximumWidth)
            let box = CGRect(
                x: padding + (maximumWidth - textWidth) / 2 - boxPadding,
                y: padding - boxPadding,
                width: textWidth + 2 * boxPadding,
                height: ceil(measured.height) + 2 * boxPadding
            )
            fillBackground(background, in: box, cornerRadius: fontSize * backgroundCornerFraction)
        }
        attributed.draw(
            with: CGRect(x: padding, y: padding, width: maximumWidth, height: ceil(measured.height)),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    private static func imagePadding(for text: TextLayer, fontSize: Double, boxPadding: Double) -> Double {
        let shadowPadding = text.hasShadow ? fontSize * shadowBlurFraction * shadowPaddingFactor * shadowBlurScale : 0
        return ceil(max(shadowPadding, boxPadding, text.strokeWidth * fontSize, minimumPadding))
    }

    private static func fillBackground(_ background: RGBAColor, in box: CGRect, cornerRadius: Double) {
        NSColor(srgbRed: background.red, green: background.green, blue: background.blue, alpha: background.alpha).setFill()
        NSBezierPath(roundedRect: box, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

    private static func attributes(for text: TextLayer, font: NSFont, scale: Double) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                srgbRed: text.color.red, green: text.color.green, blue: text.color.blue, alpha: text.color.alpha
            ),
            .paragraphStyle: paragraph,
        ]
        if text.hasShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
            shadow.shadowBlurRadius = text.fontSize * scale * shadowBlurFraction * shadowBlurScale
            shadow.shadowOffset = .zero
            attributes[.shadow] = shadow
        }
        if text.strokeWidth > 0 {
            attributes[.strokeWidth] = -text.strokeWidth * strokePercentScale
            attributes[.strokeColor] = NSColor(
                srgbRed: text.strokeColor.red, green: text.strokeColor.green,
                blue: text.strokeColor.blue, alpha: text.strokeColor.alpha
            )
        }
        return attributes
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
    }

    static func transform(for text: TextLayer, state: TextAnimationState, renderHeight: CGFloat) -> CGAffineTransform {
        CGAffineTransform(scaleX: state.scale, y: state.scale)
            .concatenating(CGAffineTransform(rotationAngle: -text.rotationInDegrees * .pi / 180))
            .concatenating(CGAffineTransform(translationX: 0, y: -state.offsetY * renderHeight))
    }

    private static func animations(
        for clip: Clip, text: TextLayer, renderHeight: CGFloat
    ) -> [(key: String, animation: CAKeyframeAnimation)] {
        let duration = clip.durationInSeconds
        let times = text.animation.samplePoints(clipDuration: duration)
        let states = times.map { text.animation.state(atClipTime: $0, clipDuration: duration) }
        let keyTimes = times.map { NSNumber(value: duration > 0 ? $0 / duration : 0) }
        func configured(_ keyPath: String, _ values: [Any]) -> CAKeyframeAnimation {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = values
            animation.keyTimes = keyTimes
            animation.calculationMode = .linear
            animation.beginTime = AVCoreAnimationBeginTimeAtZero + clip.startInSeconds
            animation.duration = duration
            animation.fillMode = .removed
            animation.isRemovedOnCompletion = true
            return animation
        }
        return [
            ("opacity", configured("opacity", states.map { Float($0.opacity) })),
            ("transform", configured("transform", states.map {
                NSValue(caTransform3D: CATransform3DMakeAffineTransform(transform(for: text, state: $0, renderHeight: renderHeight)))
            })),
        ]
    }

    private static func visibilityAnimation(for clip: Clip) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 1
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + clip.startInSeconds
        animation.duration = clip.durationInSeconds
        animation.fillMode = .removed
        animation.isRemovedOnCompletion = true
        return animation
    }
}
