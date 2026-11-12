import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Design.Spacing.comfortable) {
            Image(systemName: systemImage)
                .font(.system(size: Design.IconSize.emptyState, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(Design.Spacing.roomy)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "photo.on.rectangle", message: "Drop media here", actionTitle: "Import",
        action: {}
    )
    .frame(width: 280, height: 220)
}
