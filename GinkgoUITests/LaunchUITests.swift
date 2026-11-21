import XCTest

final class LaunchUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testHomeShowsTheNameAndTagline() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["appTitle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["appTitle"].label, "Ginkgo")
        XCTAssertTrue(app.staticTexts["tagline"].exists)
    }

    @MainActor
    func testHomeWorksAtTheLargestAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let tagline = app.staticTexts["tagline"]
        XCTAssertTrue(tagline.waitForExistence(timeout: 10))
        XCTAssertTrue(tagline.isHittable, "Tagline is cut off or off screen at the largest text size")
    }

    @MainActor
    func testHomeWorksInDarkMode() {
        XCUIDevice.shared.appearance = .dark
        addTeardownBlock { @MainActor in XCUIDevice.shared.appearance = .light }
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["appTitle"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSnapFurnitureOpensScan() {
        let app = XCUIApplication()
        app.launchArguments += ["-demoScene"]
        app.launch()
        app.buttons["snapFurniture"].tap()
        XCTAssertTrue(app.navigationBars["Scan"].waitForExistence(timeout: 5))
    }
}
