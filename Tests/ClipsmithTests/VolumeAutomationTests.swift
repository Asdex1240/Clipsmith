import XCTest
@testable import Clipsmith

final class VolumeAutomationTests: XCTestCase {
    func testPlainClipSetsItsVolumeAtTheStart() {
        var clip = TestClips.audio(start: 4, duration: 10)
        clip = clip.settingVolume(0.5)

        let steps = VolumeAutomation.steps(for: clip)

        XCTAssertEqual(
            steps,
            [VolumeStep(startInSeconds: 4, durationInSeconds: 0, startVolume: 0.5, endVolume: 0.5)])
    }

    func testFadeInRampsFromSilenceToTheClipVolume() {
        let clip = TestClips.audio(start: 0, duration: 10).settingVolume(0.8).settingFadeIn(2)

        let steps = VolumeAutomation.steps(for: clip)

        XCTAssertEqual(
            steps,
            [VolumeStep(startInSeconds: 0, durationInSeconds: 2, startVolume: 0, endVolume: 0.8)])
    }

    func testFadeOutRampsDownToSilenceEndingWithTheClip() {
        let clip = TestClips.audio(start: 5, duration: 10).settingFadeOut(3)

        let steps = VolumeAutomation.steps(for: clip)

        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(
            steps[1],
            VolumeStep(startInSeconds: 12, durationInSeconds: 3, startVolume: 1, endVolume: 0))
    }

    func testFadeInAndOutDoNotOverlap() {
        let clip = TestClips.audio(start: 0, duration: 10).settingFadeIn(6).settingFadeOut(6)

        let steps = VolumeAutomation.steps(for: clip)

        let fadeIn = steps[0]
        let fadeOut = steps[1]
        XCTAssertLessThanOrEqual(
            fadeIn.startInSeconds + fadeIn.durationInSeconds, fadeOut.startInSeconds)
    }
}
