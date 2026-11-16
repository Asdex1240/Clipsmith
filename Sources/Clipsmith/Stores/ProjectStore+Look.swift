import Foundation

extension ProjectStore {
    func applyLookTable(at url: URL, to id: Clip.ID) throws {
        _ = try LookTableStore.load(url)
        guard let clip = project.clip(withID: id) else { return }
        var look = clip.look
        look.lookTable = LookTableReference(url: url)
        setLook(of: id, to: look)
    }

    func removeLookTable(from id: Clip.ID) {
        guard let clip = project.clip(withID: id) else { return }
        var look = clip.look
        look.lookTable = nil
        setLook(of: id, to: look)
    }
}
