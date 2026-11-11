import Foundation

extension ProjectStore {
    func copySelectedClip() {
        let entries = project.clipboardEntries(for: selectedClips)
        guard !entries.isEmpty else { return }
        clipboard = entries
    }

    func cutSelectedClip() {
        copySelectedClip()
        deleteSelectedClip()
    }

    func pasteAtPlayhead() {
        guard let first = clipboard.map(\.clip.startInSeconds).min() else { return }
        place(clipboard, shiftedBy: playheadInSeconds - first)
    }

    func duplicateSelectedClip() {
        let entries = project.clipboardEntries(for: selectedClips)
        guard let first = entries.map(\.clip.startInSeconds).min(),
            let last = entries.map(\.clip.endInSeconds).max()
        else { return }
        place(entries, shiftedBy: last - first)
    }

    private func place(_ entries: [ClipboardEntry], shiftedBy offset: TimeInterval) {
        var added: [Clip.ID] = []
        mutate { added = $0.insertCopies(of: entries, shiftedBy: offset) }
        guard let last = added.last else { return }
        setSelection(Set(added), primary: last)
    }
}
