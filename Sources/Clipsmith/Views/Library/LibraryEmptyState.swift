import SwiftUI

struct LibraryEmptyState: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: Design.Spacing.comfortable) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(localized("library.empty"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localized("library.import"), action: onImport)
                .buttonStyle(.borderedProminent)
        }
        .padding(Design.Spacing.roomy)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LibraryEmptyState(onImport: {})
        .frame(width: 280, height: 260)
}
