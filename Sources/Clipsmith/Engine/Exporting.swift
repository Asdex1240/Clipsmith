import AVFoundation

protocol Exporting {
    func export(
        _ project: Project,
        with settings: ExportSettings,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws
}
