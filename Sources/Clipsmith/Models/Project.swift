import Foundation

struct Project: Codable, Identifiable {
    var id = UUID()
    var name: String
    var tracks: [Track] = [Track(kind: .video), Track(kind: .audio)]
}

struct Track: Codable, Identifiable {
    enum Kind: String, Codable { case video, audio, text }
    var id = UUID()
    var kind: Kind
    var clips: [Clip] = []
}

struct Clip: Codable, Identifiable {
    var id = UUID()
    var sourceURL: URL
    var startInSeconds: TimeInterval
    var sourceStartInSeconds: TimeInterval
    var sourceEndInSeconds: TimeInterval

    var durationInSeconds: TimeInterval { sourceEndInSeconds - sourceStartInSeconds }
}
