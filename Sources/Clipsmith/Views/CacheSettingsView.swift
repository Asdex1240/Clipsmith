import SwiftUI

struct CacheSettingsView: View {
    let controller: CacheController

    var body: some View {
        Form {
            LabeledContent(localized("settings.cache.size")) {
                Text(
                    controller.sizeInBytes.formatted(.byteCount(style: .file))
                )
                .monospacedDigit()
            }
            HStack {
                Button(localized("settings.cache.clear")) {
                    Task { await controller.clear() }
                }
                .disabled(controller.isWorking || controller.sizeInBytes == 0)
                if controller.isWorking { ProgressView().controlSize(.small) }
            }
            if let freed = controller.lastFreedBytes, !controller.isWorking {
                Text(
                    String(
                        format: localized("settings.cache.freed"),
                        freed.formatted(.byteCount(style: .file)))
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Text(localized("settings.cache.hint")).font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .task { await controller.refresh() }
    }
}
