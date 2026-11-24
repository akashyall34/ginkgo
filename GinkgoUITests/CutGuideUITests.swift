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
        let second = NSPredicate(format: "label BEGINSWITH %@", "Panel 2 of ")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: second, evaluatedWith: title)], timeout: 5), .completed,
                       title.label)
        let previous = app.buttons["previousPanel"].firstMatch
        reveal(previous, in: app)
        XCTAssertTrue(previous.isEnabled)
        previous.tap()
        let first = NSPredicate(format: "label BEGINSWITH %@", "Panel 1 of ")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: first, evaluatedWith: title)], timeout: 5), .completed,
                       title.label)
    }
}
