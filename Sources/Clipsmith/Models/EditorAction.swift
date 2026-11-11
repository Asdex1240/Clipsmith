import Foundation

enum EditorAction: CaseIterable {
    case togglePlayback
    case split
    case addText
    case addMarker
    case toggleSnapping
    case markHighlightStart
    case markHighlightEnd
    case addHighlight
    case delete
    case rippleDelete
    case trimStartToPlayhead
    case trimEndToPlayhead
    case copy
    case cut
    case paste
    case duplicate
    case selectAll
    case group
    case ungroup
    case zoomIn
    case zoomOut
    case stepBackward
    case stepForward
    case jumpBackward
    case jumpForward
    case previousEdit
    case nextEdit
    case goToStart
    case goToEnd
    case deselect

    var allowsKeyRepeat: Bool {
        switch self {
        case .zoomIn, .zoomOut, .stepBackward, .stepForward, .jumpBackward, .jumpForward,
            .previousEdit, .nextEdit:
            return true
        default:
            return false
        }
    }
}
