import Foundation

@MainActor
struct ReversibleAction {
    let undo: () -> Void
    let redo: () -> Void
}
