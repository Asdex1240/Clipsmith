import Foundation

extension ProjectStore {
    func selectClip(_ id: Clip.ID?) {
        guard let id else {
            setSelection([], primary: nil)
            return
        }
        setSelection(project.groupMembers(of: id), primary: id)
    }

    func toggleSelection(of id: Clip.ID) {
        let members = project.groupMembers(of: id)
        guard !members.isEmpty else { return }
        if selectedClipIDs.contains(id) {
            let remaining = selectedClipIDs.subtracting(members)
            setSelection(remaining, primary: selectedClipID)
        } else {
            setSelection(selectedClipIDs.union(members), primary: id)
        }
    }

    func selectAll() {
        let all = project.allClipIDs
        let candidates = [selectedClipID, selectedClips.first?.id].compactMap { $0 }
        setSelection(all, primary: candidates.first { all.contains($0) })
    }
}
