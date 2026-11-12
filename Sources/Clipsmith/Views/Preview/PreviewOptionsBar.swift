import SwiftUI

struct PreviewOptionsBar: View {
    let controller: PlayerController
    let store: ProjectStore
    var proxies: ProxyStore?
    @Binding var showsGuides: Bool
    let onSelectTimeline: () -> Void

    var body: some View {
        HStack {
            if controller.mode != .highlight { modePicker }
            Spacer()
            if controller.mode != .highlight, let proxies { fastPreview(proxies) }
            guidesToggle
            if controller.mode != .highlight { CanvasPicker(store: store) }
        }
        .padding(Design.Spacing.regular)
    }

    private var guidesToggle: some View {
        Toggle(isOn: $showsGuides) {
            Label(localized("preview.guides"), systemImage: "squareshape.dashed.squareshape")
        }
        .toggleStyle(.button)
        .help(localized("preview.guides.help"))
    }

    private func fastPreview(_ proxies: ProxyStore) -> some View {
        HStack(spacing: Design.Spacing.compact) {
            if proxies.isPreparing {
                ProgressView().controlSize(.small)
                Text(String(format: localized("preview.fast.preparing"), proxies.pendingCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle(
                localized("preview.fast"),
                isOn: Binding(get: { proxies.isEnabled }, set: { proxies.setEnabled($0) })
            )
            .toggleStyle(.button)
            .help(localized("preview.fast.help"))
        }
    }

    private var modePicker: some View {
        Picker("", selection: modeBinding) {
            Text(localized("preview.mode.source")).tag(PlayerController.Mode.source)
            Text(localized("preview.mode.timeline")).tag(PlayerController.Mode.timeline)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var modeBinding: Binding<PlayerController.Mode> {
        Binding(
            get: { controller.mode },
            set: { newMode in
                switch newMode {
                case .timeline, .highlight: onSelectTimeline()
                case .source: controller.sourceItem.map(controller.showSource)
                }
            }
        )
    }
}

#Preview {
    @Previewable @State var showsGuides = false
    PreviewOptionsBar(
        controller: PlayerController(), store: PreviewFixtures.store(), showsGuides: $showsGuides,
        onSelectTimeline: {}
    )
    .frame(width: 640)
}
