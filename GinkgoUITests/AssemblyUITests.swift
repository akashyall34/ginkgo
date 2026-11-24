import XCTest

/// Assembling the sample bench step by step, as a person sees it.
@MainActor
final class AssemblyUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testStepThroughTheBuildWithItsHardware() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "assembly", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        let title = any["assemblyTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.label.hasPrefix("Step 1 of "), title.label)
        XCTAssertTrue(any["assemblyStep"].firstMatch.label.hasPrefix("Sand the cut edges"))
        XCTAssertFalse(app.buttons["assemblyBack"].firstMatch.isEnabled)

        app.buttons["assemblyNext"].firstMatch.tap()
        let second = NSPredicate(format: "label BEGINSWITH %@", "Step 2 of ")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: second, evaluatedWith: title)], timeout: 5), .completed)
        XCTAssertTrue(any["assemblyStep"].firstMatch.label.hasPrefix("Lay the seat upside down"))

        let screws = any.matching(NSPredicate(format: "label CONTAINS %@", "wood screw, #8")).firstMatch
        reveal(screws, in: app)
        XCTAssertTrue(screws.label.hasPrefix("16 × "), screws.label)
    }
}
