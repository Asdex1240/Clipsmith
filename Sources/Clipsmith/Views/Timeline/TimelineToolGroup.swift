import SwiftUI

struct TimelineToolGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: Design.Spacing.hairline) {
            content()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, Design.Spacing.tight)
        .padding(.vertical, Design.Spacing.hairline)
        .background(
            Color.primary.opacity(Design.Opacity.chipFill),
            in: RoundedRectangle(cornerRadius: Design.Radius.medium)
        )
    }
}

#Preview {
    TimelineToolGroup {
        Button {
        } label: {
            Image(systemName: "scissors")
        }
        Button {
        } label: {
            Image(systemName: "trash")
        }
    }
    .padding()
}
