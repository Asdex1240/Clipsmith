import CoreImage
import Foundation

enum LookRendering {
    private static let maximumSharpness = 1.5
    private static let maximumVignetteIntensity = 1.2
    private static let vignetteRadiusFactor = 0.75
    private static let maximumGrainContrast = 0.35
    private static let grainFramesPerSecond = 24.0
    private static let grainOffsetSpan = 4096
    private static let grainHorizontalStep = 7919
    private static let grainVerticalStep = 104_729

    static func apply(
        _ look: LookEffects, to image: CIImage, at time: TimeInterval,
        tables: LookTableStore = .shared
    ) -> CIImage {
        guard !look.isNone else { return image }
        var result = image
        if let reference = look.lookTable { result = graded(result, with: reference, tables) }
        if look.sharpness > 0 { result = sharpened(result, by: look.sharpness) }
        if look.vignette > 0 { result = vignetted(result, by: look.vignette) }
        if look.grain > 0 { result = grained(result, by: look.grain, at: time) }
        return result
    }

    private static func graded(
        _ image: CIImage, with reference: LookTableReference, _ tables: LookTableStore
    ) -> CIImage {
        guard reference.intensity > 0, let table = tables.table(at: reference.url) else {
            return image
        }
        let graded = image.applyingFilter(
            "CIColorCubeWithColorSpace",
            parameters: [
                "inputCubeDimension": table.size, "inputCubeData": table.cubeData,
                "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB) as Any,
            ])
        guard reference.intensity < 1 else { return graded }
        return image.applyingFilter(
            "CIDissolveTransition",
            parameters: [kCIInputTargetImageKey: graded, kCIInputTimeKey: reference.intensity])
    }

    private static func sharpened(_ image: CIImage, by amount: Double) -> CIImage {
        image.applyingFilter(
            "CISharpenLuminance", parameters: [kCIInputSharpnessKey: amount * maximumSharpness])
    }

    private static func vignetted(_ image: CIImage, by amount: Double) -> CIImage {
        let extent = image.extent
        return image.applyingFilter(
            "CIVignetteEffect",
            parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputRadiusKey: max(extent.width, extent.height) * vignetteRadiusFactor,
                kCIInputIntensityKey: amount * maximumVignetteIntensity,
            ]
        )
        .cropped(to: extent)
    }

    private static func grained(_ image: CIImage, by amount: Double, at time: Double) -> CIImage {
        let contrast = amount * maximumGrainContrast
        let noise = CIFilter(name: "CIRandomGenerator")?.outputImage ?? CIImage.empty()
        let offset = grainOffset(at: time)
        let grain =
            noise
            .transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y))
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 0, y: contrast, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: contrast, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: contrast, z: 0, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBiasVector": CIVector(
                        x: 0.5 - contrast / 2, y: 0.5 - contrast / 2, z: 0.5 - contrast / 2, w: 1),
                ]
            )
            .cropped(to: image.extent)
        return grain.applyingFilter(
            "CIOverlayBlendMode", parameters: [kCIInputBackgroundImageKey: image])
    }

    private static func grainOffset(at time: TimeInterval) -> CGPoint {
        let frame = Int(time * grainFramesPerSecond)
        return CGPoint(
            x: (frame * grainHorizontalStep) % grainOffsetSpan,
            y: (frame * grainVerticalStep) % grainOffsetSpan)
    }
}
