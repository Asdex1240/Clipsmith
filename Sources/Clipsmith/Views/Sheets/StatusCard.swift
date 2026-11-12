import SwiftUI

struct StatusCard: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.cozy) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.opacity(Design.Opacity.tintBadge),
            in: RoundedRectangle(cornerRadius: Design.Radius.large)
        )
        .transition(.opacity)
    }
}

#Preview {
    VStack {
        StatusCard(
            message: "Export finished", systemImage: "checkmark.circle.fill",
            tint: Palette.successText)
        StatusCard(
            message: "The export failed", systemImage: "exclamationmark.triangle.fill",
            tint: Palette.invalidText)
    }
    .padding()
    .frame(width: 360)
}
