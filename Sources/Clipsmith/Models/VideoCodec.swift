import Foundation

enum VideoCodec: String, Codable, CaseIterable, Identifiable {
    case h264, hevc

    var id: String { rawValue }
}
