import Foundation

@MainActor
struct EditorShortcutRunner {
    let store: ProjectStore
    let player: PlayerController

    func perform(_ action: EditorAction) {
        switch action {
        case .togglePlayback: player.togglePlayback()
        case .split: store.splitAtPlayhead()
        case .addText: store.addTextAtPlayhead()
        case .addMarker: store.toggleMarkerAtPlayhead()
        case .toggleSnapping: store.toggleSnapping()
        case .delete: store.deleteSelectedClip()
        case .rippleDelete: store.rippleDeleteSelectedClip()
        case .trimStartToPlayhead: store.trimToPlayhead(edge: .leading)
        case .trimEndToPlayhead: store.trimToPlayhead(edge: .trailing)
        case .copy: store.copySelectedClip()
        case .cut: store.cutSelectedClip()
        case .paste: store.pasteAtPlayhead()
        case .duplicate: store.duplicateSelectedClip()
        case .selectAll: store.selectAll()
        case .group: store.groupSelection()
        case .ungroup: store.ungroupSelection()
        case .zoomIn: store.zoomIn()
        case .zoomOut: store.zoomOut()
        case .stepBackward: store.stepPlayhead(byFrames: -1)
        case .stepForward: store.stepPlayhead(byFrames: 1)
        case .jumpBackward: store.jumpPlayhead(bySeconds: -ProjectStore.jumpDurationInSeconds)
        case .jumpForward: store.jumpPlayhead(bySeconds: ProjectStore.jumpDurationInSeconds)
        case .previousEdit: store.goToPreviousEdit()
        case .nextEdit: store.goToNextEdit()
        case .goToStart: store.goToStart()
        case .goToEnd: store.goToEnd()
        case .deselect: store.selectClip(nil)
        }
    }
}
