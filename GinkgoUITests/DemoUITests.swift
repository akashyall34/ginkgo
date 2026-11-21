import XCTest

/// The judge walkthrough and the chatbot contrast, on the sample nightstand.
@MainActor
final class DemoUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoScene", "-openScreen", screen]
        app.launch()
        return app
    }

    func testTheContrastShowsTheChatbotFailingAndGinkgoProven() {
        let app = launch("contrast")
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["verdict"].waitForExistence(timeout: 10))
        XCTAssertTrue(any["verdict"].label.contains("Doesn't fit: 4 problems"), any["verdict"].label)
        XCTAssertFalse(app.buttons["seeItBuilt"].exists, "A failing plan can't be built")
        app.buttons["Ginkgo"].tap()
        XCTAssertTrue(any["verdict"].label.contains("Proven to fit"), any["verdict"].label)
        XCTAssertTrue(app.buttons["seeItBuilt"].waitForExistence(timeout: 3))
        app.buttons["Chatbot"].tap()
        XCTAssertTrue(any["verdict"].label.contains("Doesn't fit"), any["verdict"].label)
    }

    func testEveryDemoStepOpensAndResetReturnsToTheList() {
        let app = launch("demo")
        let screens = ["measure": "capture", "contrast": "verdict", "agent": "recordedLabel", "proof": "verdict",
                       "transform": "transformStage"]
        for (step, mark) in screens {
            app.buttons["demo-\(step)"].tap()
            XCTAssertTrue(app.descendants(matching: .any)[mark].waitForExistence(timeout: 10), step)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["demo-\(step)"].waitForExistence(timeout: 5), "Back to the list from \(step)")
        }
        app.buttons["demo-proof"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["verdict"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["demoReset"].tap()
        XCTAssertTrue(app.buttons["demo-measure"].waitForExistence(timeout: 5))
    }
}
