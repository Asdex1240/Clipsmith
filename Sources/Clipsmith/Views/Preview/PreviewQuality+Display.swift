import Foundation

extension PreviewQuality {
    var titleKey: String {
        switch self {
        case .full: return "preview.quality.full"
        case .half: return "preview.quality.half"
        case .quarter: return "preview.quality.quarter"
        }
    }
}
