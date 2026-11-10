import XCTest
@testable import Clipsmith

final class ProjectTests: XCTestCase {
    func testProjectRoundTripsThroughJSON() throws {
        var project = Project(name: "Demo")
        project.tracks[0].clips.append(makeClip(sourceStart: 1, sourceEnd: 4))

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.tracks[0].clips[0].durationInSeconds, 3)
    }

    private func makeClip(sourceStart: TimeInterval, sourceEnd: TimeInterval) -> Clip {
        Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"),
            startInSeconds: 0,
            sourceStartInSeconds: sourceStart,
            sourceEndInSeconds: sourceEnd
        )
    }
}
