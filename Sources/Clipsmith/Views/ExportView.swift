import AppKit
import SwiftUI

struct ExportView: View {
    let controller: ExportController
    @Environment(\.dismiss) private var dismiss

    private static let width: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("export.title")).font(.title2.bold())
            content
        }
        .padding(20)
        .frame(width: Self.width)
        .interactiveDismissDisabled(controller.isExporting)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state {
        case .idle: settingsForm
        case .exporting(let progress): progressView(progress)
        case .finished(let url): finishedView(url)
        case .failed(let message): failedView(message)
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Picker(localized("export.preset"), selection: presetBinding) {
                    ForEach(ExportPreset.allCases) { Text($0.title).tag(Optional($0)) }
                    Text(localized("export.preset.custom")).tag(Optional<ExportPreset>.none)
                }
                Picker(localized("export.resolution"), selection: resolutionBinding) {
                    ForEach(ExportResolution.allCases) { Text($0.title).tag($0) }
                }
                Picker(localized("export.codec"), selection: codecBinding) {
                    ForEach(VideoCodec.allCases) { Text($0.title).tag($0) }
                }
                Picker(localized("export.fps"), selection: frameRateBinding) {
                    ForEach(ExportSettings.supportedFrameRates, id: \.self) { Text("\($0) fps").tag($0) }
                }
            }
            HStack {
                Spacer()
                Button(localized("export.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(localized("export.start"), action: chooseDestinationAndStart)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func progressView(_ progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("export.exporting"))
            ProgressView(value: progress)
            HStack {
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localized("export.cancel"), action: controller.cancel)
            }
        }
    }

    private func finishedView(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localized("export.done"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            HStack {
                Spacer()
                Button(localized("export.showInFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button(localized("export.close")) { closeAndReset() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            HStack {
                Spacer()
                Button(localized("export.close")) { closeAndReset() }
                Button(localized("export.tryAgain"), action: controller.reset)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var presetBinding: Binding<ExportPreset?> {
        Binding(
            get: { controller.matchingPreset },
            set: { preset in preset.map(controller.apply) }
        )
    }

    private var resolutionBinding: Binding<ExportResolution> {
        Binding(get: { controller.settings.resolution }, set: { controller.settings.resolution = $0 })
    }

    private var codecBinding: Binding<VideoCodec> {
        Binding(get: { controller.settings.codec }, set: { controller.settings.codec = $0 })
    }

    private var frameRateBinding: Binding<Int> {
        Binding(get: { controller.settings.framesPerSecond }, set: { controller.settings.framesPerSecond = $0 })
    }

    private func chooseDestinationAndStart() {
        guard let destination = ExportDestinationPanel.choose(defaultName: controller.defaultFileName) else { return }
        controller.start(to: destination)
    }

    private func closeAndReset() {
        controller.reset()
        dismiss()
    }
}

private extension ExportPreset {
    var title: String {
        switch self {
        case .youtube1080: return localized("export.preset.youtube1080")
        case .youtube4K: return localized("export.preset.youtube4K")
        case .vertical1080: return localized("export.preset.vertical1080")
        }
    }
}

private extension ExportResolution {
    var title: String {
        switch self {
        case .hd1080: return localized("export.resolution.hd1080")
        case .uhd4K: return localized("export.resolution.uhd4K")
        }
    }
}

private extension VideoCodec {
    var title: String {
        switch self {
        case .h264: return localized("export.codec.h264")
        case .hevc: return localized("export.codec.hevc")
        }
    }
}
