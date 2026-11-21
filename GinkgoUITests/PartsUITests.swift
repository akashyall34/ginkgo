import XCTest

/// Parts and Confirm, on the offline path (no photo), through to a proven plan.
@MainActor
final class PartsUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testConfirmThePartsPickAMaterialAndMakeAPlan() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "parts", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["partsSource"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(any["partsSource"].firstMatch.label.contains("Estimated from the measured size"))
        XCTAssertTrue(any["partsFlag"].firstMatch.exists, "Says the parts are an estimate to check")
        XCTAssertTrue(any["material-top"].firstMatch.exists)
        app.buttons["planFromParts"].firstMatch.tap()
        let bench = app.buttons["idea-bench"].firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 10))
        XCTAssertTrue(bench.label.contains("reused"), bench.label)
        XCTAssertTrue(app.buttons["idea-bookshelf"].firstMatch.exists)
        bench.tap()
        // Offline: Gemini can't plan, so Ginkgo's rule-based plan takes over and says so.
        let headline = any["planningHeadline"].firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        let made = NSPredicate(format: "label CONTAINS %@", "Ginkgo made its own safe plan")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: made, evaluatedWith: headline)], timeout: 30), .completed,
                       headline.label)
        XCTAssertTrue(any["fallbackReason"].firstMatch.exists)
        app.buttons["seeProof"].firstMatch.tap()
        XCTAssertTrue(any["verdict"].waitForExistence(timeout: 10))
        XCTAssertTrue(any["verdict"].label.contains("Proven to fit"), any["verdict"].label)
    }
}

@MainActor
final class ScrewHolesUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testTappingThePanelMarksAndUnmarksAHole() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "parts", "-noGemini"]
        app.launch()
        let holes = app.buttons["holes-top"].firstMatch
        XCTAssertTrue(holes.waitForExistence(timeout: 10))
        holes.tap()
        let panel = app.descendants(matching: .any)["holePanel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["holeCount"].label.hasSuffix("1 marked"), app.staticTexts["holeCount"].label)
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["holeCount"].label.hasSuffix("0 marked"), app.staticTexts["holeCount"].label)
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)).tap()
        app.buttons["holesDone"].tap()
        XCTAssertTrue(app.buttons["holes-top"].firstMatch.label.contains("1 screw holes marked"))
    }
}
