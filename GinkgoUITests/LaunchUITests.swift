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
        XCTAssertTrue(app.buttons["snapFurniture"].exists)
    }

    @MainActor
    func testSnapFurnitureOpensScan() {
        let app = XCUIApplication()
        app.launchArguments += ["-demoScene"]
        app.launch()
        app.buttons["snapFurniture"].tap()
        XCTAssertTrue(app.navigationBars["Scan"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGuideTabShowsInstructions() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Guide"].tap()
        XCTAssertTrue(app.staticTexts["guideTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Frame one flat face"].exists)
        XCTAssertTrue(app.buttons["guideStartScan"].exists)
    }

    @MainActor
    func testMyItemsTabShowsPreviouslyScannedItemsPage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["My items"].tap()
        XCTAssertTrue(app.staticTexts["previouslyScannedTitle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAppearanceSettingsOfferAllThreeChoices() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["appearanceSettings"].tap()

        XCTAssertTrue(app.buttons["appearance-light"].exists)
        XCTAssertTrue(app.buttons["appearance-dark"].exists)
        XCTAssertTrue(app.buttons["appearance-system"].exists)

        app.buttons["appearance-dark"].tap()
        XCTAssertTrue(app.buttons["appearance-dark"].isSelected)
        app.buttons["appearance-system"].tap()
        app.buttons["appearanceDone"].tap()
    }
}

@MainActor
final class HomeEntryUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testHomeOpensTheExampleAndTheDemo() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["exampleButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["verdict"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["demoButton"].tap()
        XCTAssertTrue(app.buttons["demo-measure"].waitForExistence(timeout: 5))
        app.buttons["demoClose"].tap()
        XCTAssertTrue(app.buttons["snapFurniture"].waitForExistence(timeout: 5))
    }
}
