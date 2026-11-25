import XCTest

/// A new person can try the flow before scanning: My items offers samples, and one opens what it can become.
@MainActor
final class SamplePiecesUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testASampleOpensWhatItCanBecome() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "my-items", "-noGemini"]
        app.launch()
        let stool = app.buttons["sample-stool"].firstMatch
        for _ in 0..<6 where !stool.isHittable { app.swipeUp() }
        XCTAssertTrue(stool.waitForExistence(timeout: 5))
        XCTAssertTrue(stool.label.contains("Stool"), stool.label)
        XCTAssertTrue(stool.label.contains("parts"), stool.label)
        stool.tap()
        XCTAssertTrue(app.buttons["idea-bench"].firstMatch.waitForExistence(timeout: 10),
                      "The stool's parts open the ideas screen")
    }
}
