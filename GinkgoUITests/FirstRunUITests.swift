import XCTest

/// The first-run guide: shown on a fresh Home, five pages, skippable, and gone for good once seen.
@MainActor
final class FirstRunUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    private func launch(seen: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-noGemini", "-hasSeenFirstRunGuide", seen ? "YES" : "NO"]
        app.launch()
        return app
    }

    func testAFreshHomeShowsTheGuideAndNextWalksThroughAllFivePages() {
        let app = launch(seen: false)
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["firstRunPage-0"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Scan the furniture"].exists)
        XCTAssertEqual(any["firstRunDots"].firstMatch.label, "Page 1 of 5")
        for page in 1...4 {
            app.buttons["firstRunNext"].firstMatch.tap()
            XCTAssertTrue(any["firstRunPage-\(page)"].firstMatch.waitForExistence(timeout: 5), "Page \(page)")
            XCTAssertEqual(any["firstRunDots"].firstMatch.label, "Page \(page + 1) of 5")
        }
        XCTAssertFalse(app.buttons["firstRunNext"].exists, "The last page has no Next")
        XCTAssertFalse(app.buttons["firstRunSkip"].exists, "Nor Skip: there's nothing left to skip")
        XCTAssertTrue(app.buttons["firstRunSample"].exists)
        app.buttons["firstRunStart"].firstMatch.tap()
        XCTAssertTrue(app.buttons["firstRunStart"].waitForNonExistence(timeout: 5))
    }

    func testSkipGoesStraightToHome() {
        let app = launch(seen: false)
        let skip = app.buttons["firstRunSkip"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 5))
    }

    func testTryASampleOpensMyItemsOnTheSamples() {
        let app = launch(seen: false)
        for _ in 1...4 {
            let next = app.buttons["firstRunNext"].firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            next.tap()
        }
        let sample = app.buttons["firstRunSample"].firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        sample.tap()
        XCTAssertTrue(app.staticTexts["previouslyScannedTitle"].waitForExistence(timeout: 10),
                      "My items is the tab after Try a sample")
    }

    func testOnceSeenItNeverComesBack() {
        let app = launch(seen: true)
        XCTAssertFalse(app.buttons["firstRunSkip"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["firstRunNext"].exists)
    }
}
