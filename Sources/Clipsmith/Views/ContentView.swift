import SwiftUI

struct ContentView: View {
    @Binding var project: Project

    private enum Layout {
        static let libraryMinWidth: CGFloat = 220
        static let libraryIdealWidth: CGFloat = 280
        static let previewMinWidth: CGFloat = 400
        static let inspectorMinWidth: CGFloat = 200
        static let inspectorIdealWidth: CGFloat = 260
        static let timelineHeight: CGFloat = 240
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                placeholder(localized("panel.library"))
                    .frame(minWidth: Layout.libraryMinWidth, idealWidth: Layout.libraryIdealWidth)
                placeholder(localized("panel.preview"))
                    .frame(minWidth: Layout.previewMinWidth)
                placeholder(localized("panel.inspector"))
                    .frame(minWidth: Layout.inspectorMinWidth, idealWidth: Layout.inspectorIdealWidth)
            }
            Divider()
            placeholder(String(format: localized("panel.timeline"), project.name))
                .frame(height: Layout.timelineHeight)
        }
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    private func placeholder(_ title: String) -> some View {
        ZStack {
            Rectangle().fill(.background.secondary)
            Text(title).foregroundStyle(.secondary)
        }
    }
}
