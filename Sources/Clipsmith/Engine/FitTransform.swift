import CoreGraphics

enum FitTransform {
    static func make(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize,
        mode: FitMode = .fit,
        offset: CGPoint = .zero,
        scale userScale: Double = 1,
        rotationInDegrees: Double = 0
    ) -> CGAffineTransform {
        let oriented = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        guard oriented.width > 0, oriented.height > 0 else { return preferredTransform }
        let fitted = fittedTransform(
            preferredTransform, oriented: oriented, renderSize: renderSize, mode: mode)
        let center = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
        return
            fitted
            .concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
            .concatenating(CGAffineTransform(scaleX: userScale, y: userScale))
            .concatenating(CGAffineTransform(rotationAngle: rotationInDegrees * .pi / 180))
            .concatenating(
                CGAffineTransform(translationX: center.x + offset.x, y: center.y + offset.y))
    }

    private static func fittedTransform(
        _ preferredTransform: CGAffineTransform, oriented: CGRect, renderSize: CGSize, mode: FitMode
    ) -> CGAffineTransform {
        let widthScale = renderSize.width / oriented.width
        let heightScale = renderSize.height / oriented.height
        let scale: Double
        switch mode {
        case .fit: scale = min(widthScale, heightScale)
        case .fill: scale = max(widthScale, heightScale)
        }
        let offsetX = (renderSize.width - oriented.width * scale) / 2 - oriented.minX * scale
        let offsetY = (renderSize.height - oriented.height * scale) / 2 - oriented.minY * scale
        return
            preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }
}
