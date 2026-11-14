import CoreImage
import CoreVideo

protocol PersonMasking: AnyObject {
    func mask(for frame: CVPixelBuffer) -> CIImage?
}
