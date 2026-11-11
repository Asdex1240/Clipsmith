import Foundation

protocol CompositionBuilding {
    func build(
        from project: Project, renderSize: CGSize, framesPerSecond: Int32
    ) async throws -> BuiltComposition
}
