import Foundation

protocol NoiseReductionProcessing: Sendable {
    func process(source: URL, level: NoiseReductionLevel, destination: URL) async throws
}
