import Foundation

enum PreviewDisplayTargets {
    static func candidates(
        among displays: [ExternalDisplay], editorDisplayID: UInt32?
    ) -> [ExternalDisplay] {
        guard displays.count > 1 else { return [] }
        let excludedID = editorDisplayID ?? displays.first?.id
        return displays.filter { $0.id != excludedID }
    }

    static func isConnected(_ display: ExternalDisplay, among displays: [ExternalDisplay]) -> Bool {
        displays.contains { $0.id == display.id }
    }
}
