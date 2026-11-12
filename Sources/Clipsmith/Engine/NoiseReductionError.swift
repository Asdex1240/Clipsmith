import Foundation

enum NoiseReductionError: Error, Equatable {
    case noAudio
    case readFailed(String)
}
