import CoreImage

enum BlurredBackground {
    private static let downscale = 0.2
    private static let blurFraction = 0.03

    static func make(
        from image: CIImage, fillTransform: CGAffineTransform, canvas: CGRect
    ) -> CIImage {
        let shrink = CGAffineTransform(scaleX: downscale, y: downscale)
        let sigma = canvas.height * blurFraction * downscale
        let blurred = image.transformed(by: fillTransform.concatenating(shrink))
            .clampedToExtent()
            .applyingGaussianBlur(sigma: sigma)
            .cropped(to: canvas.applying(shrink))
        return blurred.transformed(by: CGAffineTransform(scaleX: 1 / downscale, y: 1 / downscale))
    }
}
