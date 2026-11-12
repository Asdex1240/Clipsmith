import SwiftUI

struct RelinkView: View {
    let document: DocumentController
    let actions: DocumentActions
    let onDismiss: () -> Void

    private static let width: CGFloat = 480

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.spacious) {
            SheetHeader(title: localized("relink.title"), systemImage: "exclamationmark.link")
            Text(localized("relink.message")).foregroundStyle(.secondary)
            List(document.missingMedia, id: \.self) { url in
                HStack {
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent)
                        Text(url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button(localized("relink.locate")) { locate(url) }
                }
            }
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .background(
                Color.primary.opacity(Design.Opacity.chipFill),
                in: RoundedRectangle(cornerRadius: Design.Radius.large))
            HStack {
                Spacer()
                Button(localized("relink.continue"), action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Design.Spacing.roomy)
        .frame(width: Self.width)
    }

    private func locate(_ missing: URL) {
        guard let replacement = actions.locateReplacement(for: missing) else { return }
        document.relink(missing, to: replacement)
        if document.missingMedia.isEmpty { onDismiss() }
    }
}

#Preview {
    let store = PreviewFixtures.store()
    let document = PreviewFixtures.document(store: store, library: MediaLibrary())
    RelinkView(document: document, actions: DocumentActions(document: document), onDismiss: {})
}
