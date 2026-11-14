import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case media, highlights, titles

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .media: return "sidebarTab.media"
        case .highlights: return "sidebarTab.highlights"
        case .titles: return "sidebarTab.titles"
        }
    }

    var systemImage: String {
        switch self {
        case .media: return "photo.on.rectangle"
        case .highlights: return "sparkles.rectangle.stack"
        case .titles: return "textformat"
        }
    }
}
