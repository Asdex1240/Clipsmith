import Foundation

struct FaceSample: Equatable {
    var centers: [Double]
    var sourceAspect: Double
}

protocol FaceLocating {
    func faceSample(in url: URL, at times: [TimeInterval]) async -> FaceSample?
}
