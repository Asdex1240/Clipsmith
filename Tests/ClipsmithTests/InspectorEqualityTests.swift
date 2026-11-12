import XCTest

@testable import Clipsmith

@MainActor
final class InspectorEqualityTests: XCTestCase {
    private let store = ProjectStore(project: Project(name: "Vlog"))
    private let base = PreviewFixtures.videoClip
    private let waveforms = WaveformStore()
    private let denoise = DenoiseStore()

    private func effects(_ clip: Clip) -> EffectsInspector {
        EffectsInspector(store: store, clip: clip)
    }

    private func visual(_ clip: Clip) -> VisualInspector {
        VisualInspector(store: store, clip: clip)
    }

    private func speed(_ clip: Clip) -> SpeedInspector {
        SpeedInspector(store: store, clip: clip)
    }

    private func audio(_ clip: Clip, role: Track.Role? = .main) -> AudioInspector {
        AudioInspector(
            store: store, waveforms: waveforms, denoise: denoise, clip: clip,
            trackRole: role, canDetachAudio: true)
    }

    func testEffectsIgnoreChangesThatAreNotColorOrCrop() {
        var other = base
        other.volume = 0.3
        other.scale = 2

        XCTAssertEqual(effects(base), effects(other))
    }

    func testEffectsRedrawWhenTheColorOrCropChange() {
        var colored = base
        colored.color.brightness = 0.2
        var cropped = base
        cropped.crop = CropInsets(left: 0.1, right: 0, top: 0, bottom: 0)

        XCTAssertNotEqual(effects(base), effects(colored))
        XCTAssertNotEqual(effects(base), effects(cropped))
    }

    func testVisualIgnoresColorChanges() {
        var other = base
        other.color.contrast = 1.5

        XCTAssertEqual(visual(base), visual(other))
    }

    func testVisualRedrawsWhenTheFramingChanges() {
        var other = base
        other.fitMode = .fill
        var rotated = base
        rotated.rotationInDegrees = 30

        XCTAssertNotEqual(visual(base), visual(other))
        XCTAssertNotEqual(visual(base), visual(rotated))
    }

    func testSpeedIgnoresColorAndRedrawsOnSpeed() {
        var colored = base
        colored.color.saturation = 0.5
        var faster = base
        faster.speed = 2

        XCTAssertEqual(speed(base), speed(colored))
        XCTAssertNotEqual(speed(base), speed(faster))
    }

    func testAudioIgnoresColorAndRedrawsOnVolumeOrRole() {
        var colored = base
        colored.color.temperature = 0.4
        var quieter = base
        quieter.volume = 0.4

        XCTAssertEqual(audio(base), audio(colored))
        XCTAssertNotEqual(audio(base), audio(quieter))
        XCTAssertNotEqual(audio(base, role: .main), audio(base, role: .audio))
    }

    func testDifferentClipsNeverShareAnInspector() {
        let other = TestClips.video(start: 0)

        XCTAssertNotEqual(effects(base), effects(other))
    }

    func testRarelyUsedSectionsStartCollapsed() {
        XCTAssertFalse(InspectorSectionID.silences.isExpandedByDefault)
        XCTAssertFalse(InspectorSectionID.subtitles.isExpandedByDefault)
        XCTAssertTrue(InspectorSectionID.audio.isExpandedByDefault)
        XCTAssertTrue(InspectorSectionID.color.isExpandedByDefault)
    }

    func testLocaleOptionsMatchTheSupportedLocales() {
        let identifiers = SpeechTranscriber.supportedLocales.map(\.identifier)

        XCTAssertEqual(SpeechTranscriber.supportedLocaleOptions.map(\.identifier), identifiers)
        XCTAssertTrue(SpeechTranscriber.supportedLocaleOptions.allSatisfy { !$0.name.isEmpty })
    }
}
