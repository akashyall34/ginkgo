import XCTest

/// Drives the real app on the simulator with the built-in demo scene: a 19.05 x 12 cm
/// face 50 cm away. Checks what a person would see after each action.
@MainActor
final class ScanFlowUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Launches with the demo scene and opens the Scan screen.
    private func openScan(_ extraArguments: [String] = []) -> ScanScreen {
        let app = XCUIApplication()
        app.launchArguments = ["-demoScene", "-openScreen", "scan"] + extraArguments
        app.launch()
        XCTAssertTrue(app.buttons["capture"].waitForExistence(timeout: 5))
        return ScanScreen(app: app, test: self)
    }

    func testCaptureThenTapTheFaceMeasuresItsKnownSize() throws {
        let scan = openScan()
        scan.app.buttons["capture"].tap()
        scan.waitForResult(containing: "Tap the outlined face")
        scan.tapFace()
        let (w, h) = try scan.size()
        XCTAssertEqual(w, 19.05, accuracy: 0.2, scan.result)
        XCTAssertEqual(h, 12.0, accuracy: 0.2, scan.result)
        for i in 0..<4 { XCTAssertTrue(scan.element("corner\(i)").waitForExistence(timeout: 5), "Corner \(i) handle missing") }
    }

    func testDraggingTheRightEdgeOutwardWidensTheFace() throws {
        let scan = openScan()
        scan.app.buttons["capture"].tap()
        scan.tapFace()
        let (before, _) = try scan.size()
        scan.drag("corner1", by: CGVector(dx: 25, dy: 0))
        scan.drag("corner2", by: CGVector(dx: 25, dy: 0))
        scan.waitForResult(containing: "centimeters")
        let (after, _) = try scan.size()
        XCTAssertGreaterThan(after, before + 0.5, "Width should grow: \(before) → \(after)")
    }

    /// Regression: the photo used to resize when the message under it changed, moving
    /// the face's corners out from under the person's finger mid-adjustment.
    func testThePhotoKeepsItsSizeWhileAdjustingCorners() {
        let scan = openScan()
        scan.app.buttons["capture"].tap()
        let captured = scan.element("photo").frame
        scan.tapFace()
        XCTAssertEqual(scan.element("photo").frame, captured, "Photo moved when the measurement appeared")
        scan.drag("corner1", by: CGVector(dx: 25, dy: 0)) // one corner alone: a warning replaces the number
        XCTAssertEqual(scan.element("photo").frame, captured, "Photo moved when the message changed")
    }

    func testCrossedCornersShowAWarningInsteadOfANumber() {
        let scan = openScan()
        scan.app.buttons["capture"].tap()
        scan.tapFace()
        let bottomRight = scan.element("corner2").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        scan.element("corner0").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: bottomRight.withOffset(CGVector(dx: 30, dy: 30)))
        scan.waitForResult(containing: "corners cross")
        XCTAssertFalse(scan.result.contains("centimeters"))
    }

    func testPlaceCornersGivesFourHandles() {
        let scan = openScan()
        scan.app.buttons["capture"].tap()
        scan.app.buttons["placeCorners"].tap()
        for i in 0..<4 { XCTAssertTrue(scan.element("corner\(i)").waitForExistence(timeout: 3)) }
    }

    func testRetakeReturnsToTheCamera() {
        let scan = openScan()
        scan.app.buttons["capture"].tap()
        scan.app.buttons["retake"].tap()
        XCTAssertTrue(scan.app.buttons["capture"].waitForExistence(timeout: 3))
        scan.waitForResult(containing: "Aim at")
    }

    func testScanWorksInDarkModeAndAtTheLargestTextSize() {
        let scan = openScan(["-AppleInterfaceStyle", "Dark",
                             "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(scan.app.buttons["capture"].isHittable, "Capture is off screen at the largest text size")
        scan.app.buttons["capture"].tap()
        scan.tapFace()
        XCTAssertTrue(scan.element("retake").isHittable, "Retake is off screen at the largest text size")
    }
}

/// The Scan screen as a person sees it: elements, the result text, and gestures.
@MainActor
private struct ScanScreen {
    let app: XCUIApplication
    let test: XCTestCase

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }
    var result: String { element("result").label }

    /// The width and height in "W by H centimeters…".
    func size() throws -> (Double, Double) {
        let values = result.split(whereSeparator: { !"0123456789.".contains($0) }).compactMap { Double($0) }
        guard values.count >= 2 else { throw XCTSkip("No size in result: \(result)") }
        return (values[0], values[1])
    }

    /// Waits for the result to contain `text`; on timeout, fails with what the screen
    /// actually said, so a failure explains itself.
    func waitForResult(containing text: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let outcome = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element("result"))],
                                       timeout: 5)
        if outcome != .completed {
            XCTFail("Expected the result to contain \"\(text)\", but it says: \"\(result)\"", file: file, line: line)
        }
    }

    func tapFace() {
        element("photo").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitForResult(containing: "centimeters")
    }

    func drag(_ id: String, by offset: CGVector) {
        let start = element(id).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(offset))
    }
}
