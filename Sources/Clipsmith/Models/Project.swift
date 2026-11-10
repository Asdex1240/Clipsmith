import Foundation

struct Project: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var canvas: CanvasFormat = .landscape
    var tracks: [Track] = [Track(role: .text), Track(role: .broll), Track(role: .main), Track(role: .audio)]
}
