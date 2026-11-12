import SwiftUI

struct SheetHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Design.Spacing.cozy) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: Design.Size.headerBadge, height: Design.Size.headerBadge)
                .background(Color.accentColor.opacity(Design.Opacity.tintBadge), in: Circle())
                .accessibilityHidden(true)
            Text(title).font(.title2.bold())
        }
    }
}

#Preview {
    SheetHeader(title: "Export video", systemImage: "square.and.arrow.up")
        .padding()
}
