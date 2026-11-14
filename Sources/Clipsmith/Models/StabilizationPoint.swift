import Foundation

struct StabilizationPoint: Codable, Equatable {
    let timeInSeconds: TimeInterval
    let dx: Double
    let dy: Double
}
