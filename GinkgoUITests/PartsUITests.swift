import XCTest

/// Parts and Confirm, on the offline path (no photo), through to a proven plan.
@MainActor
final class PartsUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testConfirmThePartsPickAMaterialAndMakeAPlan() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "parts"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["partsSource"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(any["partsSource"].firstMatch.label.contains("Estimated from the measured size"))
        XCTAssertTrue(any["partsFlag"].firstMatch.exists, "Says the parts are an estimate to check")
        XCTAssertTrue(any["material-top"].firstMatch.exists)
        app.buttons["planFromParts"].firstMatch.tap()
        XCTAssertTrue(any["verdict"].waitForExistence(timeout: 10))
        XCTAssertTrue(any["verdict"].label.contains("Proven to fit"), any["verdict"].label)
    }
}
