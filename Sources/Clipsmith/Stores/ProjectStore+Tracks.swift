import Foundation

extension ProjectStore {
    func addTrack(role: Track.Role) {
        mutate { $0.addTrack(role: role) }
    }

    func removeTrack(_ id: Track.ID) {
        mutate { $0.removeTrack(id) }
        let existing = selectedClipIDs.intersection(project.allClipIDs)
        if existing != selectedClipIDs { setSelection(existing, primary: selectedClipID) }
    }

    func moveTrack(_ id: Track.ID, direction: TrackMoveDirection) {
        mutate { $0.moveTrack(id, direction: direction) }
    }

    func renameTrack(_ id: Track.ID, to name: String) {
        mutate(coalescingKey: "track-name-\(id)") { $0.renameTrack(id, to: name) }
    }
}
