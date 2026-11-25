import XCTest

/// Parts and Confirm, on the offline path (no photo), through to a proven plan.
@MainActor
final class PartsUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testConfirmThePartsPickAMaterialAndMakeAPlan() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "parts", "-noGemini"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["partsSource"].firstMatch.waitForExistence(timeout: 10))
        // Wait for the words, not just the element: under load the label is read before it finishes drawing.
        let estimated = NSPredicate(format: "label CONTAINS %@", "Estimated from the measured size")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: estimated, evaluatedWith: any["partsSource"].firstMatch)],
                                        timeout: 5), .completed, any["partsSource"].firstMatch.label)
        XCTAssertTrue(any["partsFlag"].firstMatch.waitForExistence(timeout: 5), "Says the parts are an estimate to check")
        XCTAssertTrue(any["material-top"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["rereadParts"].exists, "Offline: no photo reading on offer")
        // Each material is a guess until the person confirms it; a guessed seat panel can't promise a bench.
        for id in ["top", "side_left", "side_right"] {
            let confirm = app.buttons["confirmMaterial-\(id)"].firstMatch
            reveal(confirm, in: app)
            confirm.tap()
            XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "\(id): the guess note goes once confirmed")
        }
        // The seat comes from the top: its wood lines must be checked, or it's rated as across the grain.
        let grain = any["grain-top"].firstMatch
        reveal(grain, in: app)
        grain.tap()
        // The choices open as a menu: its items aren't plain buttons, so match any element with the words.
        let sideToSide = any.matching(NSPredicate(format: "label == %@", "Side to side")).firstMatch
        XCTAssertTrue(sideToSide.waitForExistence(timeout: 5), "The wood-lines menu didn't open")
        sideToSide.tap()
        let plan = app.buttons["planFromParts"].firstMatch
        reveal(plan, in: app)
        plan.tap()
        let bench = app.buttons["idea-bench"].firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 10))
        XCTAssertTrue(bench.label.contains("reused"), bench.label)
        XCTAssertTrue(app.buttons["idea-bookshelf"].firstMatch.waitForExistence(timeout: 5))
        bench.tap()
        // Offline: Gemini can't plan, so Ginkgo's rule-based plan takes over and says so.
        let headline = any["planningHeadline"].firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        let made = NSPredicate(format: "label CONTAINS %@", "Ginkgo made its own safe plan")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: made, evaluatedWith: headline)], timeout: 30), .completed,
                       headline.label)
        XCTAssertTrue(any["fallbackReason"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["improvePlan"].exists, "Offline: nothing to improve with")
        app.buttons["seeProof"].firstMatch.tap()
        XCTAssertTrue(any["verdict"].waitForExistence(timeout: 10))
        XCTAssertTrue(any["verdict"].label.contains("Proven to fit"), any["verdict"].label)
    }
}

@MainActor
final class ScrewHolesUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    func testTappingThePanelMarksAndUnmarksAHole() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "parts", "-noGemini"]
        app.launch()
        let holes = app.buttons["holes-top"].firstMatch
        XCTAssertTrue(holes.waitForExistence(timeout: 10))
        holes.tap()
        let panel = app.descendants(matching: .any)["holePanel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["holeCount"].label.hasSuffix("1 marked"), app.staticTexts["holeCount"].label)
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["holeCount"].label.hasSuffix("0 marked"), app.staticTexts["holeCount"].label)
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)).tap()
        app.buttons["holesDone"].tap()
        XCTAssertTrue(app.buttons["holes-top"].firstMatch.label.contains("1 screw holes marked"))
    }
}

/// Scrolls until the element is on screen (lists load rows lazily): down the list first, then back up.
@MainActor
func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
    for _ in 0..<10 where !(element.exists && element.isHittable) { app.swipeDown() }
    XCTAssertTrue(element.exists && element.isHittable, "Couldn't scroll to \(element)", file: file, line: line)
}
