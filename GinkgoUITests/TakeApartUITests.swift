import XCTest

/// Step 2 offline: the standard take-apart order for the sample nightstand, ticked off step by step.
@MainActor
final class TakeApartUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testTheOfflineGuideListsTheStepsAndTicksThemOff() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "take-apart", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        let source = any["takeApartSource"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertTrue(source.label.contains("standard order"), source.label)
        let first = app.buttons["takeApartStep-1"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.contains("glass"), "Safety comes first: \(first.label)")
        XCTAssertTrue(app.buttons["takeApartStep-2"].firstMatch.exists)
        first.tap()
        let ticked = NSPredicate(format: "value == %@", "Done")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: ticked, evaluatedWith: first)], timeout: 5), .completed,
                       String(describing: first.value))
        XCTAssertTrue(any["takeApartProgress"].firstMatch.label.hasPrefix("1 of"), any["takeApartProgress"].firstMatch.label)
        first.tap()
        XCTAssertEqual(first.value as? String, "Not done")
    }
}
