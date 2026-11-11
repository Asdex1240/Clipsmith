import Foundation

struct Marker: Codable, Identifiable, Equatable {
    static let toggleToleranceInSeconds: TimeInterval = 0.05

    var id = UUID()
    var timeInSeconds: TimeInterval
    var name = ""
}
