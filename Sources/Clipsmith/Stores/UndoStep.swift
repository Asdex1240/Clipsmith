import Foundation

enum UndoStep {
    case snapshot(Project)
    case action(ReversibleAction)
}
