import SwiftUI

struct InspectorSection<Content: View>: View {
    let id: InspectorSectionID
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static var expandedRotation: Double { 90 }

    init(_ id: InspectorSectionID, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
        _isExpanded = AppStorage(wrappedValue: id.isExpandedByDefault, id.storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            header
            if isExpanded {
                content()
            }
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var header: some View {
        Button(action: toggle) {
            HStack(spacing: Design.Spacing.regular) {
                Image(systemName: id.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: Design.Size.sectionIcon)
                Text(localized(String.LocalizationValue(id.titleKey)))
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(chevronRotation))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized(String.LocalizationValue(id.titleKey)))
        .accessibilityValue(expansionDescription)
    }

    private var chevronRotation: Double {
        if isExpanded { return Self.expandedRotation }
        return 0
    }

    private var expansionDescription: String {
        if isExpanded { return localized("inspector.section.expanded") }
        return localized("inspector.section.collapsed")
    }

    private func toggle() {
        guard !reduceMotion else {
            isExpanded.toggle()
            return
        }
        withAnimation(.easeInOut(duration: Design.Motion.quick)) { isExpanded.toggle() }
    }
}

#Preview {
    InspectorSection(.audio) {
        Text("Content")
    }
    .padding()
    .frame(width: 260)
}
