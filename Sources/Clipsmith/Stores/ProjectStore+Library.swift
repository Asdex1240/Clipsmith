import Foundation

extension ProjectStore {
    func remove(_ item: MediaItem, from library: MediaLibrary) {
        guard let index = library.removeItem(item.id) else { return }
        recordReversibleAction(
            ReversibleAction(
                undo: { library.insert(item, at: index) },
                redo: { library.removeItem(item.id) }))
    }
}
