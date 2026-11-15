import Foundation

extension LibraryLayout {
    var titleKey: String {
        switch self {
        case .grid: return "library.layout.grid"
        case .list: return "library.layout.list"
        }
    }

    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}
