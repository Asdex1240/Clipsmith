import SwiftUI

struct InspectorView: View {
    let store: ProjectStore
    let subtitles: SubtitleController
    let waveforms: WaveformStore
    let denoise: DenoiseStore

    private var multipleSelectionHintKey: String.LocalizationValue {
        if store.selectionIsGrouped { return "inspector.multiple.grouped" }
        return "inspector.multiple.hint"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localized("panel.inspector"))
                .font(.headline)
                .padding(Design.Spacing.regular)
            Divider()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.hasMultipleSelected {
            multipleSelection
        } else if let clip = store.selectedClip {
            ScrollView {
                VStack(alignment: .leading, spacing: Design.Spacing.spacious) {
                    if hasVisualControls(for: clip) {
                        VisualInspector(
                            store: store,
                            clip: clip.presented(atTimelineTime: store.playheadInSeconds))
                        EffectsInspector(store: store, clip: clip)
                    }
                    if clip.textLayer != nil {
                        TextInspector(store: store, clip: clip)
                    }
                    if hasSpeedControls(for: clip) {
                        SpeedInspector(store: store, clip: clip)
                    }
                    if hasAudioControls(for: clip) {
                        AudioInspector(
                            store: store, waveforms: waveforms, denoise: denoise, clip: clip)
                    }
                    if hasAudioControls(for: clip) {
                        SilenceInspector(store: store, waveforms: waveforms, clip: clip)
                    }
                    if hasAudioControls(for: clip) {
                        SubtitleInspector(subtitles: subtitles, clip: clip)
                    }
                    if clip.isAudioDetached {
                        Text(localized("inspector.audio.detached"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Design.Spacing.comfortable)
            }
        } else {
            ZStack {
                Rectangle().fill(.background.secondary)
                Text(localized("inspector.empty"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }

    private var multipleSelection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
            Text(String(format: localized("inspector.multiple.title"), store.selectedClipIDs.count))
                .font(.subheadline.bold())
            Text(localized(multipleSelectionHintKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(localized("timeline.group"), action: store.groupSelection)
                    .disabled(!store.canGroupSelection)
                Button(localized("timeline.ungroup"), action: store.ungroupSelection)
                    .disabled(!store.selectionIsGrouped)
            }
            HStack {
                Button(localized("shortcut.duplicate"), action: store.duplicateSelectedClip)
                Button(
                    localized("timeline.delete"), role: .destructive,
                    action: store.deleteSelectedClip)
            }
            Spacer()
        }
        .padding(Design.Spacing.comfortable)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func hasVisualControls(for clip: Clip) -> Bool {
        guard clip.mediaKind == .video || clip.mediaKind == .image else { return false }
        let role = store.project.trackRole(ofClip: clip.id)
        return role == .main || role == .broll
    }

    private func hasSpeedControls(for clip: Clip) -> Bool {
        guard clip.supportsSpeed else { return false }
        return store.project.trackRole(ofClip: clip.id).map {
            [.main, .broll, .audio].contains($0)
        } ?? false
    }

    private func hasAudioControls(for clip: Clip) -> Bool {
        guard clip.mediaKind == .video || clip.mediaKind == .audio, !clip.isAudioDetached else {
            return false
        }
        return store.project.trackRole(ofClip: clip.id)?.playsAudio ?? false
    }
}

#Preview {
    let store = PreviewFixtures.store()
    InspectorView(
        store: store, subtitles: SubtitleController(store: store), waveforms: WaveformStore(),
        denoise: DenoiseStore())
}
