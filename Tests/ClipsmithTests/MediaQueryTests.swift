import XCTest

@testable import Clipsmith

final class MediaQueryTests: XCTestCase {
    private func item(_ name: String, _ kind: MediaKind, _ seconds: TimeInterval) -> MediaItem {
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"), kind: kind, durationInSeconds: seconds)
    }

    private let items: [MediaItem] = [
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/Beach day.mov"), kind: .video, durationInSeconds: 30),
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/city walk.mp4"), kind: .video, durationInSeconds: 120),
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/theme.m4a"), kind: .audio, durationInSeconds: 200),
        MediaItem(url: URL(fileURLWithPath: "/tmp/cover.jpg"), kind: .image, durationInSeconds: 5),
    ]

    func testAnEmptyQueryKeepsEverythingInOrder() {
        XCTAssertEqual(MediaQuery().apply(to: items), items)
        XCTAssertFalse(MediaQuery().isFiltering)
    }

    func testTheFilterKeepsOnlyThatKind() {
        var query = MediaQuery()
        query.filter = .video

        XCTAssertEqual(query.apply(to: items).map(\.name), ["Beach day.mov", "city walk.mp4"])
        XCTAssertTrue(query.isFiltering)
    }

    func testSearchIgnoresCaseAndSurroundingSpaces() {
        var query = MediaQuery()
        query.searchText = "  BEACH "

        XCTAssertEqual(query.apply(to: items).map(\.name), ["Beach day.mov"])
    }

    func testSearchAndFilterCombine() {
        var query = MediaQuery()
        query.searchText = "c"
        query.filter = .image

        XCTAssertEqual(query.apply(to: items).map(\.name), ["cover.jpg"])
    }

    func testBlankSearchDoesNotCountAsFiltering() {
        var query = MediaQuery()
        query.searchText = "   "

        XCTAssertFalse(query.isFiltering)
        XCTAssertEqual(query.apply(to: items).count, items.count)
    }

    func testSortingByNameIsNaturalAndCaseInsensitive() {
        var query = MediaQuery()
        query.sort = .name

        XCTAssertEqual(
            query.apply(to: items).map(\.name),
            ["Beach day.mov", "city walk.mp4", "cover.jpg", "theme.m4a"])
    }

    func testSortingByDurationPutsTheLongestFirst() {
        var query = MediaQuery()
        query.sort = .duration

        XCTAssertEqual(query.apply(to: items).map(\.durationInSeconds), [200, 120, 30, 5])
    }

    func testNothingMatchingGivesAnEmptyList() {
        var query = MediaQuery()
        query.searchText = "zzz"

        XCTAssertTrue(query.apply(to: items).isEmpty)
    }

    func testFilterAcceptance() {
        XCTAssertTrue(MediaFilter.all.accepts(.text))
        XCTAssertTrue(MediaFilter.audio.accepts(.audio))
        XCTAssertFalse(MediaFilter.audio.accepts(.video))
        XCTAssertFalse(MediaFilter.image.accepts(.video))
    }

    func testEveryFilterAndSortHasATranslatedTitleAndIcon() {
        for filter in MediaFilter.allCases {
            XCTAssertNotEqual(localized(String.LocalizationValue(filter.titleKey)), filter.titleKey)
            XCTAssertFalse(filter.systemImage.isEmpty)
        }
        for sort in MediaSort.allCases {
            XCTAssertNotEqual(localized(String.LocalizationValue(sort.titleKey)), sort.titleKey)
        }
    }
}
