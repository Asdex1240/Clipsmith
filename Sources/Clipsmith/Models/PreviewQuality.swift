import CoreGraphics
import Foundation

enum PreviewQuality: String, CaseIterable, Identifiable {
    case full, half, quarter

    var id: String { rawValue }

    var scale: Double {
        switch self {
        case .full: return 1
        case .half: return 0.5
        case .quarter: return 0.25
        }
    }

    func renderSize(for canvas: CanvasFormat) -> CGSize {
        CGSize(
            width: Self.evenPixels(Double(canvas.width) * scale),
            height: Self.evenPixels(Double(canvas.height) * scale))
    }

    private static func evenPixels(_ value: Double) -> Double {
        max(2, (value / 2).rounded() * 2)
    }
}
