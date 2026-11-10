import Foundation

/// A labelled point on the timeline, used to flag moments to come back to.
struct Marker: Codable, Identifiable, Equatable {
    static let toggleToleranceInSeconds: TimeInterval = 0.05

    var id = UUID()
    var timeInSeconds: TimeInterval
    var name = ""
}
