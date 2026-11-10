import Foundation

protocol CompositionBuilding {
    func build(from project: Project) async throws -> BuiltComposition
}

struct CompositionBuilder: CompositionBuilding {
    private static let assemblyOrder: [Track.Role] = [.main, .broll, .audio]

    var stillImages: StillImageVideoMaking = StillImageVideoWriter()

    func build(from project: Project) async throws -> BuiltComposition {
        let assembler = CompositionAssembler(renderSize: project.canvas.renderSize, stillImages: stillImages)
        for role in Self.assemblyOrder {
            for clip in project.track(withRole: role)?.clips ?? [] {
                await assembler.add(clip, role: role)
            }
        }
        return assembler.finish(segments: CompositionPlanner.segments(for: project))
    }
}
