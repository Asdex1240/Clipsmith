import Foundation

struct ClipboardEntry {
    let clip: Clip
    let trackID: Track.ID
}

extension Project {
    func clipboardEntries(for clips: [Clip]) -> [ClipboardEntry] {
        clips.compactMap { clip in
            location(of: clip.id).map { ClipboardEntry(clip: clip, trackID: tracks[$0.track].id) }
        }
    }

    @discardableResult
    mutating func insertCopies(
        of entries: [ClipboardEntry], shiftedBy offset: TimeInterval
    ) -> [Clip.ID] {
        var groups: [UUID: UUID] = [:]
        var added: [Clip.ID] = []
        for entry in entries {
            var copy = entry.clip
            copy.id = UUID()
            copy.startInSeconds = max(0, entry.clip.startInSeconds + offset)
            if let group = copy.groupID {
                let copiedGroup = groups[group] ?? UUID()
                groups[group] = copiedGroup
                copy.groupID = copiedGroup
            }
            guard let trackID = destinationTrackID(for: entry, copy: copy),
                addClip(copy, toTrack: trackID)
            else { continue }
            added.append(copy.id)
        }
        return added
    }

    private func destinationTrackID(for entry: ClipboardEntry, copy: Clip) -> Track.ID? {
        tracks.first { $0.id == entry.trackID }?.id
            ?? track(withRole: Track.Role.preferred(for: copy.mediaKind))?.id
    }
}
