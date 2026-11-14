import AVFoundation
import XCTest

@testable import Clipsmith

final class StabilizationTests: XCTestCase {
    private func samples(_ deltas: [(Double, Double)], step: TimeInterval = 0.125) -> [MotionSample]
    {
        deltas.enumerated().map {
            MotionSample(
                timeInSeconds: Double($0.offset) * step, dx: $0.element.0, dy: $0.element.1)
        }
    }

    // MARK: Planner

    func testTooFewSamplesGiveNoPlan() {
        XCTAssertNil(
            StabilizationPlanner.plan(from: samples([(0, 0), (0.01, 0)]), strength: .normal))
    }

    func testAShakyHorizontalShotIsPulledBackTowardItsSmoothPath() throws {
        let shaky = samples((0..<40).map { ($0 % 2 == 0 ? 0.01 : -0.01, 0) })

        let plan = try XCTUnwrap(StabilizationPlanner.plan(from: shaky, strength: .normal))

        let raw = shaky.reduce(into: [Double]()) { path, sample in
            path.append((path.last ?? 0) + sample.dx)
        }
        let residual = zip(raw, plan.points).map { abs($0 + $1.dx) }.max() ?? 1
        XCTAssertLessThan(residual, raw.map(abs).max() ?? 1)
        XCTAssertGreaterThan(plan.zoom, 1)
    }

    func testASteadyPanIsLeftAlone() throws {
        let pan = samples((0..<40).map { _ in (0.004, 0) })

        let plan = try XCTUnwrap(StabilizationPlanner.plan(from: pan, strength: .light))

        let middle = plan.points[20]
        XCTAssertEqual(middle.dx, 0, accuracy: 1e-9)
    }

    func testAStillShotNeedsNoZoom() throws {
        let still = samples((0..<20).map { _ in (0, 0) })

        let plan = try XCTUnwrap(StabilizationPlanner.plan(from: still, strength: .strong))

        XCTAssertEqual(plan.zoom, 1, accuracy: 1e-9)
        XCTAssertTrue(plan.points.allSatisfy { $0.dx == 0 && $0.dy == 0 })
    }

    func testZoomNeverExceedsTheStrengthCap() throws {
        let violent = samples((0..<40).map { ($0 % 2 == 0 ? 0.2 : -0.2, 0.2) })

        for strength in StabilizationStrength.allCases {
            let plan = try XCTUnwrap(StabilizationPlanner.plan(from: violent, strength: strength))

            XCTAssertLessThanOrEqual(plan.zoom, strength.maximumZoom + 1e-9)
            let limit = (plan.zoom - 1) / 2
            XCTAssertTrue(plan.points.allSatisfy { abs($0.dx) <= limit && abs($0.dy) <= limit })
        }
    }

    func testStrongerSettingsSmoothMore() {
        XCTAssertLessThan(
            StabilizationStrength.light.smoothingWindowInSeconds,
            StabilizationStrength.strong.smoothingWindowInSeconds)
        XCTAssertLessThan(
            StabilizationStrength.light.maximumZoom, StabilizationStrength.strong.maximumZoom)
    }

    func testSamplesAreOrderedByTimeBeforePlanning() throws {
        let shuffled = samples((0..<10).map { _ in (0.01, 0) }).reversed()

        let plan = try XCTUnwrap(
            StabilizationPlanner.plan(from: Array(shuffled), strength: .normal))

        XCTAssertEqual(plan.points.map(\.timeInSeconds), plan.points.map(\.timeInSeconds).sorted())
    }

    // MARK: Correction lookup

    func testCorrectionInterpolatesBetweenPointsAndHoldsTheEnds() {
        let stabilization = Stabilization(
            points: [
                StabilizationPoint(timeInSeconds: 1, dx: 0, dy: 0),
                StabilizationPoint(timeInSeconds: 3, dx: 0.02, dy: -0.04),
            ], zoom: 1.1)

        XCTAssertEqual(stabilization.correction(atSourceTime: 0).dx, 0)
        XCTAssertEqual(stabilization.correction(atSourceTime: 2).dx, 0.01, accuracy: 1e-9)
        XCTAssertEqual(stabilization.correction(atSourceTime: 2).dy, -0.02, accuracy: 1e-9)
        XCTAssertEqual(stabilization.correction(atSourceTime: 9).dx, 0.02)
        XCTAssertEqual(stabilization.correction(atSourceTime: 2).zoom, 1.1)
    }

    func testNoPointsMeansNoCorrection() {
        XCTAssertEqual(
            Stabilization(points: [], zoom: 1.2).correction(atSourceTime: 3), .none)
    }

    // MARK: Clip

    func testTheCorrectionFollowsTheSourceTimeOfATrimmedFastClip() {
        var clip = TestClips.video(start: 5, sourceStart: 10, sourceEnd: 20)
        clip.speed = 2
        clip.stabilization = Stabilization(
            points: [
                StabilizationPoint(timeInSeconds: 10, dx: 0, dy: 0),
                StabilizationPoint(timeInSeconds: 20, dx: 0.1, dy: 0),
            ], zoom: 1.1)

        XCTAssertEqual(clip.stabilizationCorrection(atClipTime: 0).dx, 0, accuracy: 1e-9)
        XCTAssertEqual(clip.stabilizationCorrection(atClipTime: 2.5).dx, 0.05, accuracy: 1e-9)
    }

    func testAStabilizedClipNeedsTheFrameCompositor() {
        var clip = TestClips.video(start: 0)
        XCTAssertFalse(clip.hasLookEffects)

        clip.stabilization = Stabilization(points: [], zoom: 1)

        XCTAssertTrue(clip.hasLookEffects)
        XCTAssertTrue(clip.needsAnimatedLayer)
    }

    func testStabilizationRoundTripsThroughJSONAndIsOmittedWhenAbsent() throws {
        var clip = TestClips.video(start: 0)
        XCTAssertFalse(
            try XCTUnwrap(String(data: JSONEncoder().encode(clip), encoding: .utf8))
                .contains("stabilization"))

        clip.stabilization = Stabilization(
            points: [StabilizationPoint(timeInSeconds: 1, dx: 0.01, dy: 0.02)], zoom: 1.05)
        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))

        XCTAssertEqual(decoded.stabilization, clip.stabilization)
    }

    func testSplittingKeepsTheStabilizationOnBothHalves() throws {
        var clip = TestClips.video(start: 0, sourceEnd: 20)
        clip.stabilization = Stabilization(
            points: [StabilizationPoint(timeInSeconds: 0, dx: 0.01, dy: 0)], zoom: 1.05)

        let halves = try XCTUnwrap(clip.split(at: 8))

        XCTAssertEqual(halves.left.stabilization, clip.stabilization)
        XCTAssertEqual(halves.right.stabilization, clip.stabilization)
    }

    // MARK: Transform

    private let natural = CGSize(width: 1920, height: 1080)
    private let canvas = CGSize(width: 1920, height: 1080)

    private func center(of transform: CGAffineTransform) -> CGPoint {
        CGPoint(x: natural.width / 2, y: natural.height / 2).applying(transform)
    }

    func testWithoutACorrectionTheTransformIsUntouched() {
        let plain = FitTransform.make(
            naturalSize: natural, preferredTransform: .identity, renderSize: canvas)
        let corrected = FitTransform.make(
            naturalSize: natural, preferredTransform: .identity, renderSize: canvas,
            stabilization: .none)

        XCTAssertEqual(plain, corrected)
    }

    func testAPositiveHorizontalCorrectionMovesThePictureRightByThatFractionOfItsWidth() {
        let correction = Stabilization.Correction(dx: 0.01, dy: 0, zoom: 1)

        let moved = FitTransform.make(
            naturalSize: natural, preferredTransform: .identity, renderSize: canvas,
            stabilization: correction)

        XCTAssertEqual(center(of: moved).x, 960 + 19.2, accuracy: 1e-6)
        XCTAssertEqual(center(of: moved).y, 540, accuracy: 1e-6)
    }

    func testAPositiveVerticalCorrectionMovesThePictureDown() {
        let correction = Stabilization.Correction(dx: 0, dy: 0.02, zoom: 1)

        let moved = FitTransform.make(
            naturalSize: natural, preferredTransform: .identity, renderSize: canvas,
            stabilization: correction)

        XCTAssertEqual(center(of: moved).y, 540 + 0.02 * 1080, accuracy: 1e-6)
    }

    func testZoomScalesThePictureAroundTheCenterOfTheCanvas() {
        let zoomed = FitTransform.make(
            naturalSize: natural, preferredTransform: .identity, renderSize: canvas,
            stabilization: Stabilization.Correction(dx: 0, dy: 0, zoom: 1.1))

        let corner = CGPoint(x: 0, y: 0).applying(zoomed)
        XCTAssertEqual(corner.x, 960 - 960 * 1.1, accuracy: 1e-6)
        XCTAssertEqual(center(of: zoomed).x, 960, accuracy: 1e-6)
    }

    func testTheShiftIsRelativeToTheDisplayedPictureNotTheCanvas() {
        let vertical = CGSize(width: 1080, height: 1920)
        let correction = Stabilization.Correction(dx: 0.1, dy: 0, zoom: 1)

        let moved = FitTransform.make(
            naturalSize: natural, preferredTransform: .identity, renderSize: vertical,
            mode: .fit, stabilization: correction)

        XCTAssertEqual(center(of: moved).x, 540 + 0.1 * 1080, accuracy: 1e-6)
    }

    func testRenderLayersApplyTheClipsCorrection() {
        var clip = TestClips.video(start: 0, sourceEnd: 10)
        clip.stabilization = Stabilization(
            points: [StabilizationPoint(timeInSeconds: 0, dx: 0.05, dy: 0)], zoom: 1)
        let layer = RenderLayer(
            trackID: 1, clip: clip, naturalSize: natural, preferredTransform: .identity,
            renderSize: canvas)

        let transform = layer.transform(at: 3)

        XCTAssertEqual(center(of: transform).x, 960 + 0.05 * 1920, accuracy: 1e-6)
    }
}

@MainActor
final class StabilizationStoreTests: XCTestCase {
    private var store = ProjectStore(project: Project(name: "Vlog"))
    private var clipID: Clip.ID!

    override func setUp() async throws {
        store = ProjectStore(project: Project(name: "Vlog"))
        let main = store.project.track(withRole: .main)!.id
        store.addMedia(TestClips.mediaItem(duration: 10), toTrack: main, at: 0)
        clipID = try XCTUnwrap(store.selectedClipID)
    }

    func testStabilizingStoresThePlanOnTheClip() async throws {
        let applied = await store.stabilizeClip(
            clipID, strength: .normal, using: ShakyAnalyzer()
        ) { _ in }

        XCTAssertTrue(applied)
        XCTAssertNotNil(store.project.clip(withID: clipID)?.stabilization)
    }

    func testTheAnalysisSeesTheSourceRangeOfTheClip() async throws {
        let analyzer = ShakyAnalyzer()

        await store.stabilizeClip(clipID, strength: .normal, using: analyzer) { _ in }

        XCTAssertEqual(analyzer.requestedRange, 0...10)
    }

    func testNothingToAnalyzeLeavesTheClipUntouched() async {
        let applied = await store.stabilizeClip(
            clipID, strength: .normal, using: ShakyAnalyzer(returnsMotion: false)
        ) { _ in }

        XCTAssertFalse(applied)
        XCTAssertNil(store.project.clip(withID: clipID)?.stabilization)
        XCTAssertFalse(store.canUndo && store.project.clip(withID: clipID)?.stabilization != nil)
    }

    func testStabilizingAndRemovingAreUndoable() async {
        await store.stabilizeClip(clipID, strength: .light, using: ShakyAnalyzer()) { _ in }

        store.clearStabilization(of: clipID)
        XCTAssertNil(store.project.clip(withID: clipID)?.stabilization)

        store.undo()
        XCTAssertNotNil(store.project.clip(withID: clipID)?.stabilization)
    }

    func testOnlyVideoClipsCanBeStabilized() async throws {
        let audio = store.project.track(withRole: .audio)!.id
        store.addMedia(TestClips.mediaItem(kind: .audio, duration: 5), toTrack: audio, at: 0)
        let audioID = try XCTUnwrap(store.selectedClipID)

        let applied = await store.stabilizeClip(
            audioID, strength: .normal, using: ShakyAnalyzer()
        ) { _ in }

        XCTAssertFalse(applied)
    }

    func testLockedTracksAreNotChanged() async {
        let main = store.project.track(withRole: .main)!.id
        store.toggleLock(ofTrack: main)

        let applied = await store.stabilizeClip(
            clipID, strength: .normal, using: ShakyAnalyzer()
        ) { _ in }

        XCTAssertFalse(applied)
    }

    func testProgressIsReportedByTheAnalyzer() async {
        let recorder = ProgressRecorder()

        await store.stabilizeClip(clipID, strength: .normal, using: ShakyAnalyzer()) {
            recorder.record($0)
        }

        XCTAssertEqual(recorder.values.last, 1)
    }

    func testEveryStrengthHasATranslatedTitleAndSectionIsListed() {
        for strength in StabilizationStrength.allCases {
            XCTAssertNotEqual(
                localized(String.LocalizationValue(strength.titleKey)), strength.titleKey)
        }
        XCTAssertNotEqual(
            localized(String.LocalizationValue(InspectorSectionID.stabilization.titleKey)),
            InspectorSectionID.stabilization.titleKey)
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    var values: [Double] { lock.withLock { recorded } }

    func record(_ value: Double) {
        lock.withLock { recorded.append(value) }
    }
}

private final class ShakyAnalyzer: StabilizationAnalyzing, @unchecked Sendable {
    private let lock = NSLock()
    private var range: ClosedRange<TimeInterval>?
    private let returnsMotion: Bool

    var requestedRange: ClosedRange<TimeInterval>? { lock.withLock { range } }

    init(returnsMotion: Bool = true) {
        self.returnsMotion = returnsMotion
    }

    func motion(
        in url: URL, sourceRange: ClosedRange<TimeInterval>,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> [MotionSample]? {
        lock.withLock { range = sourceRange }
        progress(0.5)
        progress(1)
        guard returnsMotion else { return nil }
        return (0..<30).map {
            MotionSample(
                timeInSeconds: Double($0) * 0.125, dx: $0 % 2 == 0 ? 0.01 : -0.01, dy: 0)
        }
    }
}
