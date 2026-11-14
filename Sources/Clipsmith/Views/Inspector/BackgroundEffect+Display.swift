import Foundation

extension BackgroundEffect {
    var titleKey: String {
        switch self {
        case .remove: return "inspector.background.remove"
        case .blur: return "inspector.background.blur"
        }
    }
}
