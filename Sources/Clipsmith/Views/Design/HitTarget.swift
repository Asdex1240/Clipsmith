import SwiftUI

extension View {
    func minimumHitTarget() -> some View {
        frame(minWidth: Design.Size.minimumHitTarget, minHeight: Design.Size.minimumHitTarget)
            .contentShape(Rectangle())
    }
}
