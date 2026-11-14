import Foundation

extension ProjectStore {
    @discardableResult
    func stabilizeClip(
        _ id: Clip.ID, strength: StabilizationStrength, using analyzer: StabilizationAnalyzing,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> Bool {
        guard let clip = project.clip(withID: id), clip.mediaKind == .video,
            let url = clip.sourceURL, !project.isLocked(id)
        else { return false }
        let range = clip.sourceStartInSeconds...clip.sourceEndInSeconds
        guard let samples = await analyzer.motion(in: url, sourceRange: range, progress: progress),
            let plan = StabilizationPlanner.plan(from: samples, strength: strength)
        else { return false }
        mutate { $0.setStabilization(of: id, to: plan) }
        return true
    }

    func clearStabilization(of id: Clip.ID) {
        mutate { $0.setStabilization(of: id, to: nil) }
    }
}
