import Foundation

/// How a clip is framed when its proportion differs from the canvas.
enum FitMode: String, Codable, CaseIterable, Identifiable {
    /// The whole clip is visible; the rest of the canvas stays black.
    case fit
    /// The clip covers the whole canvas; whatever sticks out is cropped.
    case fill

    var id: String { rawValue }
}
