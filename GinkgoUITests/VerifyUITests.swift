import XCTest

/// Verify before cutting, from a proven plan, using tape readings.
@MainActor
final class VerifyUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    private func openVerify() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoScene", "-openScreen", "example"]
        app.launch()
        XCTAssertTrue(app.buttons["verify"].waitForExistence(timeout: 10))
        app.buttons["verify"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["verifyStatus"].waitForExistence(timeout: 5))
        return app
    }

    private func type(_ value: String, into index: Int, _ app: XCUIApplication) {
        let field = app.textFields["tape-\(index)"].firstMatch
        field.tap()
        field.typeText(value)
        app.buttons["use-\(index)"].firstMatch.tap()
    }

    func testMeasuringWhatThePlanAssumesVerifiesItAndShowsTheSteps() {
        let app = openVerify()
        let status = app.descendants(matching: .any)["verifyStatus"]
        XCTAssertTrue(status.label.contains("to measure"), status.label)
        // The example's checks: top width 46.0, top height 40.0, left side width 40.0 cm.
        for (index, value) in ["46", "40", "40"].enumerated() where app.textFields["tape-\(index)"].firstMatch.exists {
            type(value, into: index, app)
        }
        XCTAssertTrue(status.label.contains("Verified"), status.label)
        XCTAssertTrue(app.staticTexts.matching(identifier: "step").firstMatch.waitForExistence(timeout: 3))
    }

    func testAPanelTooSmallWithdrawsThePlan() {
        let app = openVerify()
        type("41", into: 0, app) // the top is 5 cm narrower than the scan said
        let status = app.descendants(matching: .any)["verifyStatus"]
        XCTAssertTrue(status.label.contains("Withdrawn"), status.label)
        XCTAssertFalse(app.staticTexts.matching(identifier: "step").firstMatch.exists, "No steps for a withdrawn plan")
    }

    func testMeasureOpensTheScanScreen() {
        let app = openVerify()
        app.buttons["measure-0"].firstMatch.tap()
        XCTAssertTrue(app.buttons["capture"].waitForExistence(timeout: 5))
    }
}
