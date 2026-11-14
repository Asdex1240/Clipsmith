import CoreGraphics

enum FitTransform {
    static func make(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize,
        mode: FitMode = .fit,
        offset: CGPoint = .zero,
        scale userScale: Double = 1,
        rotationInDegrees: Double = 0,
        stabilization: Stabilization.Correction = .none
    ) -> CGAffineTransform {
        let oriented = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        guard oriented.width > 0, oriented.height > 0 else { return preferredTransform }
        let fitScale = fitScale(oriented: oriented, renderSize: renderSize, mode: mode)
        let center = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
        let fitted = stabilized(
            fittedTransform(
                preferredTransform, oriented: oriented, renderSize: renderSize, scale: fitScale),
            correction: stabilization, center: center,
            displayedSize: CGSize(
                width: oriented.width * fitScale, height: oriented.height * fitScale))
        return
            fitted
            .concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
            .concatenating(CGAffineTransform(scaleX: userScale, y: userScale))
            .concatenating(CGAffineTransform(rotationAngle: rotationInDegrees * .pi / 180))
            .concatenating(
                CGAffineTransform(translationX: center.x + offset.x, y: center.y + offset.y))
    }

    private static func stabilized(
        _ fitted: CGAffineTransform, correction: Stabilization.Correction, center: CGPoint,
        displayedSize: CGSize
    ) -> CGAffineTransform {
        guard correction != .none else { return fitted }
        return
            fitted
            .concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
            .concatenating(CGAffineTransform(scaleX: correction.zoom, y: correction.zoom))
            .concatenating(
                CGAffineTransform(
                    translationX: center.x + correction.dx * displayedSize.width,
                    y: center.y + correction.dy * displayedSize.height))
    }

    private static func fitScale(oriented: CGRect, renderSize: CGSize, mode: FitMode) -> Double {
        let widthScale = renderSize.width / oriented.width
        let heightScale = renderSize.height / oriented.height
        switch mode {
        case .fit, .blur: return min(widthScale, heightScale)
        case .fill: return max(widthScale, heightScale)
        }
    }

    private static func fittedTransform(
        _ preferredTransform: CGAffineTransform, oriented: CGRect, renderSize: CGSize,
        scale: Double
    ) -> CGAffineTransform {
        let offsetX = (renderSize.width - oriented.width * scale) / 2 - oriented.minX * scale
        let offsetY = (renderSize.height - oriented.height * scale) / 2 - oriented.minY * scale
        return
            preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }
}
