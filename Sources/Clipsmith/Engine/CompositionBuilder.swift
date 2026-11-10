import Foundation

protocol CompositionBuilding {
    func build(from project: Project, renderSize: CGSize, framesPerSecond: Int32) async throws -> BuiltComposition
}

extension CompositionBuilding {
    func build(from project: Project) async throws -> BuiltComposition {
        try await build(
            from: project,
            renderSize: project.canvas.renderSize,
            framesPerSecond: CompositionBuilder.previewFramesPerSecond
        )
    }
}

struct CompositionBuilder: CompositionBuilding {
    static let previewFramesPerSecond: Int32 = 30
    private static let assemblyOrder: [Track.Role] = [.main, .broll, .audio, .text]

    var stillImages: StillImageVideoMaking = StillImageVideoWriter()

    func build(from project: Project, renderSize: CGSize, framesPerSecond: Int32) async throws -> BuiltComposition {
        let assembler = CompositionAssembler(
            renderSize: renderSize,
            framesPerSecond: framesPerSecond,
            stillImages: stillImages
        )
        for role in Self.assemblyOrder {
            for clip in project.track(withRole: role)?.clips ?? [] {
                await assembler.add(clip, role: role)
            }
        }
        return assembler.finish(segments: CompositionPlanner.segments(for: project))
    }
}
