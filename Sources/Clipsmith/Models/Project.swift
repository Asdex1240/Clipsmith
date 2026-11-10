import Foundation

struct Project: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var canvas: CanvasFormat = .landscape
    /// When true, the canvas takes the proportion of the first video or image added to an empty timeline.
    var autoFitCanvas = true
    var tracks: [Track] = [Track(role: .text), Track(role: .broll), Track(role: .main), Track(role: .audio)]
}

extension Project {
    private enum CodingKeys: String, CodingKey {
        case id, name, canvas, autoFitCanvas, tracks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        canvas = try container.decode(CanvasFormat.self, forKey: .canvas)
        autoFitCanvas = try container.decodeIfPresent(Bool.self, forKey: .autoFitCanvas) ?? true
        tracks = try container.decode([Track].self, forKey: .tracks)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(canvas, forKey: .canvas)
        try container.encode(autoFitCanvas, forKey: .autoFitCanvas)
        try container.encode(tracks, forKey: .tracks)
    }
}
