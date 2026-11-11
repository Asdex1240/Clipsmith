import Foundation

protocol FaceLocating {
    func faceSample(in url: URL, at times: [TimeInterval]) async -> FaceSample?
}
