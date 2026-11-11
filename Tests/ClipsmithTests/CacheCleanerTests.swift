import XCTest
@testable import Clipsmith

final class CacheCleanerTests: XCTestCase {
    private var root: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 3600

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cache-cleaner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func makeFile(
        _ name: String, bytes: Int = 100, usedDaysAgo: Double = 0, in folder: String = "a"
    ) throws -> URL {
        let directory = root.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-usedDaysAgo * day)], ofItemAtPath: url.path)
        return url
    }

    private func cleaner(maximumBytes: Int64 = 1_000_000) -> CacheCleaner {
        CacheCleaner(
            directories: [root.appendingPathComponent("a"), root.appendingPathComponent("b")],
            maximumAge: 30 * day, maximumBytes: maximumBytes)
    }

    private func modified(_ url: URL) -> Date? {
        try? URL(fileURLWithPath: url.path).resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
    }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    func testFilesNotUsedForAMonthAreRemovedAndRecentOnesStay() throws {
        let old = try makeFile("old.mov", usedDaysAgo: 31)
        let recent = try makeFile("recent.mov", usedDaysAgo: 29)

        let report = cleaner().clean(now: now)

        XCTAssertFalse(exists(old))
        XCTAssertTrue(exists(recent))
        XCTAssertEqual(report, CacheCleaner.Report(removedFiles: 1, removedBytes: 100))
    }

    func testStalePartialFilesGoAfterADayButFreshOnesAreKept() throws {
        let stale = try makeFile("x.partial.caf", usedDaysAgo: 2)
        let fresh = try makeFile("y.mov.partial", usedDaysAgo: 0)

        cleaner().clean(now: now)

        XCTAssertFalse(exists(stale))
        XCTAssertTrue(exists(fresh))
    }

    func testWhenOverTheLimitTheLeastRecentlyUsedGoFirst() throws {
        let oldest = try makeFile("1.mov", bytes: 400, usedDaysAgo: 20)
        let middle = try makeFile("2.mov", bytes: 400, usedDaysAgo: 10)
        let newest = try makeFile("3.mov", bytes: 400, usedDaysAgo: 1)

        cleaner(maximumBytes: 800).clean(now: now)

        XCTAssertFalse(exists(oldest))
        XCTAssertTrue(exists(middle))
        XCTAssertTrue(exists(newest))
    }

    func testNothingIsRemovedWhenEverythingIsRecentAndSmall() throws {
        let file = try makeFile("ok.mov", usedDaysAgo: 1)

        XCTAssertEqual(cleaner().clean(now: now), CacheCleaner.Report())
        XCTAssertTrue(exists(file))
    }

    func testClearAllEmptiesEveryFolderButKeepsTheFolders() throws {
        try makeFile("1.mov", bytes: 300)
        try makeFile("2.mov", bytes: 200, in: "b")

        let report = cleaner().clearAll()

        XCTAssertEqual(report.removedFiles, 2)
        XCTAssertEqual(report.removedBytes, 500)
        XCTAssertEqual(cleaner().totalSize(), 0)
        XCTAssertTrue(exists(root.appendingPathComponent("a")))
    }

    func testTotalSizeAddsAllFoldersAndMissingOnesCountAsEmpty() throws {
        try makeFile("1.mov", bytes: 300)
        try makeFile("2.mov", bytes: 200, in: "b")
        let withMissing = CacheCleaner(directories: [
            root.appendingPathComponent("a"), root.appendingPathComponent("nope"),
        ])

        XCTAssertEqual(cleaner().totalSize(), 500)
        XCTAssertEqual(withMissing.totalSize(), 300)
    }

    func testTouchRefreshesOldFilesButLeavesRecentOnesAlone() throws {
        let old = try makeFile("old.mov", usedDaysAgo: 20)
        let recent = try makeFile("recent.mov")
        let before = modified(recent)

        CacheCleaner.touch(old, now: now)
        CacheCleaner.touch(recent, now: Date())

        XCTAssertEqual(modified(old), now)
        XCTAssertEqual(modified(recent), before)
    }

    func testAFileUsedAgainSurvivesTheCleanup() throws {
        let reused = try makeFile("reused.mov", usedDaysAgo: 40)

        CacheCleaner.touch(reused, now: now)
        cleaner().clean(now: now)

        XCTAssertTrue(exists(reused))
    }
}
