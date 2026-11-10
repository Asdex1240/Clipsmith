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

enum TextOverlayLayers {
    private static let maximumWidthFraction = 0.9
    private static let shadowOpacity = 0.6
    private static let shadowBlurFraction = 0.008
    private static let shadowPaddingFactor = 3.0

    static func makeContainer(for overlay: TextOverlay) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: overlay.renderSize)
        for clip in overlay.clips {
            guard let text = clip.textLayer, let layer = makeLayer(for: clip, text: text, renderSize: overlay.renderSize) else {
                continue
            }
            layer.opacity = 0
            layer.add(visibilityAnimation(for: clip), forKey: "visibility")
            container.addSublayer(layer)
        }
        return container
    }

    /// Layers for the live preview: not tied to any player item, shown or hidden by the caller via `opacity`.
    static func makeStaticLayers(for overlay: TextOverlay) -> [(clip: Clip, layer: CALayer)] {
        overlay.clips.compactMap { clip in
            guard let text = clip.textLayer,
                  let layer = makeLayer(for: clip, text: text, renderSize: overlay.renderSize) else { return nil }
            return (clip, layer)
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
        return layer
    }

    /// Size of the visible text in render-space points, used for hit-testing in the preview.
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

    private static func renderImage(of text: TextLayer, scale: Double, maximumWidth: CGFloat) -> CGImage? {
        let fontSize = text.fontSize * scale
        let font = NSFont(name: text.fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        let attributed = NSAttributedString(string: text.content, attributes: attributes(for: text, font: font, scale: scale))
        let measured = attributed.boundingRect(
            with: CGSize(width: maximumWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let padding = ceil(fontSize * shadowBlurFraction * shadowPaddingFactor * 10)
        let width = Int(ceil(maximumWidth + 2 * padding))
        let height = Int(ceil(measured.height + 2 * padding))
        guard width > 0, height > 0, let context = makeContext(width: width, height: height) else { return nil }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        attributed.draw(
            with: CGRect(x: padding, y: padding, width: maximumWidth, height: ceil(measured.height)),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    private static func attributes(for text: TextLayer, font: NSFont, scale: Double) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
        shadow.shadowBlurRadius = text.fontSize * scale * shadowBlurFraction * 10
        shadow.shadowOffset = .zero
        return [
            .font: font,
            .foregroundColor: NSColor(
                srgbRed: text.color.red, green: text.color.green, blue: text.color.blue, alpha: text.color.alpha
            ),
            .paragraphStyle: paragraph,
            .shadow: shadow,
        ]
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
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
