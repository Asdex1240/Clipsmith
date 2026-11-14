import SwiftUI

struct TitlesView: View {
    let store: ProjectStore

    private static let cardMinimumWidth: CGFloat = 130

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
                Text(localized("title.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: Self.cardMinimumWidth),
                            spacing: Design.Spacing.cozy)
                    ],
                    spacing: Design.Spacing.cozy
                ) {
                    ForEach(TitleTemplate.allCases) { template in
                        TitleTemplateCard(template: template) { store.addTitle(template) }
                    }
                }
            }
            .padding(Design.Spacing.comfortable)
        }
    }
}

#Preview {
    TitlesView(store: PreviewFixtures.store())
        .frame(width: 300, height: 420)
}
