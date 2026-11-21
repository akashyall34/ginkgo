import XCTest

/// The Proof screen, opened from Home's example: a nightstand turned into a bench.
@MainActor
final class ProofUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func openExample(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "example"] + arguments
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["verdict"].waitForExistence(timeout: 5))
        return app
    }

    func testTheExampleIsProvenToFitPieceByPiece() {
        let app = openExample()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["verdict"].label.contains("Proven to fit"), any["verdict"].label)
        XCTAssertTrue(any["verdict"].label.contains("70% of the wood reused"))
        let cuts = any.matching(identifier: "cut")
        XCTAssertEqual(cuts.count, 3)
        XCTAssertTrue(cuts.element(boundBy: 0).label.hasPrefix("Seat, 45.2 × 36.2 cm"), cuts.element(boundBy: 0).label)
        XCTAssertTrue(cuts.element(boundBy: 0).label.hasSuffix("Fits."))
    }

    func testSagCuttingPlanAndChecksAreAllThere() {
        let app = openExample()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["sag"].label.contains("0.49 of 0.69 mm allowed"), any["sag"].label)
        XCTAssertTrue(any["sag"].label.contains("Within the limit"))
        XCTAssertEqual(any.matching(identifier: "sheet").count, 3)
        app.swipeUp()
        let checks = any.matching(identifier: "check")
        XCTAssertTrue(checks.element(boundBy: 0).waitForExistence(timeout: 3))
        XCTAssertTrue(checks.element(boundBy: 0).label.contains("tight fit"), checks.element(boundBy: 0).label)
    }

    func testReadableInDarkModeAtTheLargestTextSize() {
        XCUIDevice.shared.appearance = .dark
        addTeardownBlock { @MainActor in XCUIDevice.shared.appearance = .light }
        let app = openExample(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "proof-dark"
        shot.lifetime = .keepAlways
        add(shot)
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["verdict"].isHittable)
        // Everything is reachable by scrolling, down to the last check.
        for _ in 0..<8 where !(any.matching(identifier: "check").firstMatch.exists
                                && any.matching(identifier: "check").firstMatch.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(any.matching(identifier: "check").firstMatch.isHittable)
    }
}
