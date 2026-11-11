import SwiftUI

struct SidebarView: View {
    let store: ProjectStore
    let highlightExporter: HighlightExportController
    let library: MediaLibrary
    let thumbnails: ThumbnailGenerating
    let waveforms: WaveformStore
    @Binding var selection: MediaItem.ID?
    let onAddToTimeline: (MediaItem) -> Void
    @State private var tab = SidebarTab.media

    var body: some View {
        VStack(spacing: 0) {
            Picker(localized("panel.library"), selection: $tab) {
                ForEach(SidebarTab.allCases) { tab in
                    Label(
                        localized(String.LocalizationValue(tab.titleKey)),
                        systemImage: tab.systemImage
                    )
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(Design.Spacing.regular)
            Divider()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .media:
            LibraryView(
                library: library, thumbnails: thumbnails, selection: $selection,
                onAddToTimeline: onAddToTimeline)
        case .highlights:
            HighlightsView(store: store, exporter: highlightExporter, waveforms: waveforms)
        }
    }
}

#Preview {
    @Previewable @State var selection: MediaItem.ID?
    let store = PreviewFixtures.store()
    SidebarView(
        store: store, highlightExporter: HighlightExportController(store: store),
        library: MediaLibrary(),
        thumbnails: CachedThumbnailGenerator(), waveforms: WaveformStore(), selection: $selection, onAddToTimeline: { _ in }
    )
    .frame(width: 280, height: 420)
}
