import XCTest
@testable import Ginkgo

final class FirstRunGuideTests: XCTestCase {
    func testItShowsOnceOnHomeOnly() {
        XCTAssertTrue(FirstRunGuide.shouldShow(seen: false, initialTab: 0))
        XCTAssertFalse(FirstRunGuide.shouldShow(seen: true, initialTab: 0), "Never again once seen")
        XCTAssertFalse(FirstRunGuide.shouldShow(seen: false, initialTab: 1), "My items opens on its own")
        XCTAssertFalse(FirstRunGuide.shouldShow(seen: false, initialTab: 2), "So does Guide")
    }

    func testFivePagesInOrderEachWithWords() {
        XCTAssertEqual(FirstRunGuide.pages.map(\.id), [0, 1, 2, 3, 4])
        XCTAssertTrue(FirstRunGuide.pages.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty && !$0.symbol.isEmpty })
        XCTAssertEqual(Set(FirstRunGuide.pages.map(\.title)).count, 5, "Each page has its own title")
    }

    func testThePagesFollowTheRealFlow() {
        XCTAssertEqual(FirstRunGuide.pages.map(\.title),
                       ["Scan the furniture", "Take it apart", "Plan what to build", "Cut and assemble",
                        "No LiDAR? Try a sample"])
    }

    func testTheLastPageSaysWhoNeedsLiDARAndPointsToSamples() throws {
        let last = try XCTUnwrap(FirstRunGuide.pages.last)
        XCTAssertTrue(last.detail.contains("LiDAR") && last.detail.contains("sample"), last.detail)
    }
}
