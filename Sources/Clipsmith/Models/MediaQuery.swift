import Foundation

struct MediaQuery: Equatable {
    var searchText = ""
    var filter = MediaFilter.all
    var sort = MediaSort.added

    var isFiltering: Bool {
        !trimmedSearch.isEmpty || filter != .all
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to items: [MediaItem]) -> [MediaItem] {
        let matching = items.filter { matches($0) }
        switch sort {
        case .added:
            return matching
        case .name:
            return matching.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .duration:
            return matching.sorted { $0.durationInSeconds > $1.durationInSeconds }
        }
    }

    private func matches(_ item: MediaItem) -> Bool {
        guard filter.accepts(item.kind) else { return false }
        guard !trimmedSearch.isEmpty else { return true }
        return item.name.localizedStandardContains(trimmedSearch)
    }
}
