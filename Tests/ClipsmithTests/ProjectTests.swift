import XCTest
@testable import Clipsmith

final class ProjectTests: XCTestCase {
    func testProjectRoundTripsThroughJSON() throws {
        var project = Project(name: "Demo")
        let mainTrack = try XCTUnwrap(project.track(withRole: .main))
        project.addClip(TestClips.video(start: 0, sourceStart: 1, sourceEnd: 4), toTrack: mainTrack.id)

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        let decodedClip = try XCTUnwrap(decoded.track(withRole: .main)?.clips.first)
        XCTAssertEqual(decodedClip.durationInSeconds, 3)
    }

    func testNewProjectHasTextBrollMainAndAudioTracksInThatOrder() {
        let project = Project(name: "Demo")

        XCTAssertEqual(project.tracks.map(\.role), [.text, .broll, .main, .audio])
    }
}
