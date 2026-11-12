import SwiftUI

struct PresetGrid<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    let isSelected: (Item) -> Bool
    let action: (Item) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: Design.Size.presetColumn), spacing: Design.Spacing.tight)
            ],
            alignment: .leading,
            spacing: Design.Spacing.tight
        ) {
            ForEach(items, id: \.self) { item in
                chip(for: item)
            }
        }
    }

    private func chip(for item: Item) -> some View {
        let selected = isSelected(item)
        return Button {
            action(item)
        } label: {
            Text(title(item))
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Design.Spacing.compact)
                .background(
                    fill(selected: selected),
                    in: RoundedRectangle(cornerRadius: Design.Radius.medium)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Radius.medium)
                        .stroke(border(selected: selected), lineWidth: Design.Stroke.hairline)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .motion(value: selected)
        .accessibilityAddTraits(traits(selected: selected))
    }

    private func fill(selected: Bool) -> Color {
        if selected { return Color.accentColor.opacity(Design.Opacity.selectedChipFill) }
        return Color.primary.opacity(Design.Opacity.chipFill)
    }

    private func border(selected: Bool) -> Color {
        if selected { return .accentColor }
        return .clear
    }

    private func traits(selected: Bool) -> AccessibilityTraits {
        if selected { return .isSelected }
        return []
    }
}

#Preview {
    PresetGrid(
        items: ["None", "Warm", "Cool", "Vivid"], title: { $0 }, isSelected: { $0 == "Warm" },
        action: { _ in }
    )
    .padding()
    .frame(width: 260)
}
