import XCTest

/// Marking the cuts on the sample bench, as a person sees it on the simulator (no AR there).
@MainActor
final class CutGuideUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testStepThroughEachPanelsMarks() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "cuts", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        let title = any["cutPanelTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.label.hasPrefix("Panel 1 of "), title.label)
        let firstStep = any["cutStep"].firstMatch
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        XCTAssertTrue(firstStep.label.contains("mm from the left edge"), firstStep.label)
        XCTAssertFalse(app.buttons["previousPanel"].firstMatch.isEnabled, "Nothing before the first panel")
        XCTAssertFalse(app.buttons["markWithAR"].firstMatch.exists, "No AR on the simulator: the marks still work")

        let next = app.buttons["nextPanel"].firstMatch
        reveal(next, in: app)
        next.tap()
        scrollToTop(app, until: title)
        let second = NSPredicate(format: "label BEGINSWITH %@", "Panel 2 of ")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: second, evaluatedWith: title)], timeout: 5), .completed)
        let previous = app.buttons["previousPanel"].firstMatch
        reveal(previous, in: app)
        XCTAssertTrue(previous.isEnabled)
        previous.tap()
        scrollToTop(app, until: title)
        let first = NSPredicate(format: "label BEGINSWITH %@", "Panel 1 of ")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: first, evaluatedWith: title)], timeout: 5), .completed)
    }

    /// Lists drop rows that scroll off screen; scroll back up until the element is there again.
    private func scrollToTop(_ app: XCUIApplication, until element: XCUIElement) {
        for _ in 0..<6 where !element.exists { app.swipeDown() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }
}

/// Checking a cut piece by scanning it, on the simulator's demo scene (a 19.05 × 12 cm board: far smaller than the
/// sample bench's pieces, so it can't pass as one).
@MainActor
final class CutCheckUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testScanningAPieceGivesItAVerdict() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "cut-check", "-demoScene", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        let summary = any["cutCheckSummary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.hasPrefix("Scan each piece after cutting"), summary.label)

        app.buttons["scanPiece-seat"].firstMatch.tap()
        XCTAssertTrue(app.buttons["capture"].waitForExistence(timeout: 5))
        app.buttons["capture"].tap()
        let center = DemoCorners.center
        let photo = any["photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.coordinate(withNormalizedOffset: center).tap()
        let use = app.buttons["useMeasurement"].firstMatch
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        use.tap()

        let verdict = any["pieceVerdict-seat"].firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        XCTAssertTrue(verdict.label.contains("short"), "A 19 × 12 cm board is far short of the seat: \(verdict.label)")
    }
}

/// The demo face's center on the photo (it sits in the middle of the frame).
enum DemoCorners {
    static let center = CGVector(dx: 0.5, dy: 0.5)
}
