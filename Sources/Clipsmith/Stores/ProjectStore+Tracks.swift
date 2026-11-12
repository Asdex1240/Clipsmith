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

    func toggleMute(ofTrack id: Track.ID) {
        mutate { $0.toggleMute(ofTrack: id) }
    }

    func toggleVisibility(ofTrack id: Track.ID) {
        mutate { $0.toggleVisibility(ofTrack: id) }
    }

    func toggleLock(ofTrack id: Track.ID) {
        mutate { $0.toggleLock(ofTrack: id) }
    }

    func renameTrack(_ id: Track.ID, to name: String) {
        mutate(coalescingKey: "track-name-\(id)") { $0.renameTrack(id, to: name) }
    }
}
