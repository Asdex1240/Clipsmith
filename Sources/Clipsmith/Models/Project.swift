import Foundation

struct Project: Codable, Identifiable {
    var id = UUID()
    var name: String
    var tracks: [Track] = [Track(role: .broll), Track(role: .main), Track(role: .audio)]
}
