import XCTest

/// The sample nightstand turning into the bench.
@MainActor
final class TransformUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testTransformAndBackAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "transform"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["transformStage"].waitForExistence(timeout: 10))
        let transform = app.buttons["transformButton"]
        XCTAssertEqual(transform.label, "Transform")
        XCTAssertTrue(app.buttons["arButton"].isHittable)
        transform.tap()
        XCTAssertEqual(transform.label, "Show the original")
        XCTAssertEqual(any["transformStage"].label, "The new build in 3D")
        transform.tap()
        XCTAssertEqual(transform.label, "Transform")
    }

    func testAProvenPlanOpensTheTransform() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "example"]
        app.launch()
        XCTAssertTrue(app.buttons["seeItBuilt"].waitForExistence(timeout: 10))
        app.buttons["seeItBuilt"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["transformStage"].waitForExistence(timeout: 10))
    }
}
