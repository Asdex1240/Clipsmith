import AVFoundation

extension AVAssetExportSession {
    func exportUntilFinishedOrCancelled() async {
        nonisolated(unsafe) let shared = self
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                shared.exportAsynchronously { continuation.resume() }
            }
        } onCancel: {
            shared.cancelExport()
        }
    }
}
