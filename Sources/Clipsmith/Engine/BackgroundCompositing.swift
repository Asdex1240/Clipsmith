import CoreImage

enum BackgroundCompositing {
    static let blurFraction = 0.04

    static func apply(_ effect: BackgroundEffect, to image: CIImage, mask: CIImage) -> CIImage {
        switch effect {
        case .remove:
            return blended(
                image, over: CIImage(color: .clear).cropped(to: image.extent), mask: mask)
        case .blur:
            let sigma = image.extent.height * blurFraction
            let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: sigma)
                .cropped(to: image.extent)
            return blended(image, over: blurred, mask: mask)
        }
    }

    private static func blended(
        _ foreground: CIImage, over background: CIImage, mask: CIImage
    )
        -> CIImage
    {
        foreground.applyingFilter(
            "CIBlendWithMask",
            parameters: [kCIInputBackgroundImageKey: background, kCIInputMaskImageKey: mask]
        )
        .cropped(to: foreground.extent)
    }
}
