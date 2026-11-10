import CoreGraphics

enum FitTransform {
    static func make(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize
    ) -> CGAffineTransform {
        let oriented = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        guard oriented.width > 0, oriented.height > 0 else { return preferredTransform }
        let scale = min(renderSize.width / oriented.width, renderSize.height / oriented.height)
        let offsetX = (renderSize.width - oriented.width * scale) / 2 - oriented.minX * scale
        let offsetY = (renderSize.height - oriented.height * scale) / 2 - oriented.minY * scale
        return preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }
}
