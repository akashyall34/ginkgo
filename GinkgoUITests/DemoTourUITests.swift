import XCTest

/// The filmed app half of the demo video: the real app, driven at a calm, human pace, while the
/// screen is recorded. Each test is one shot. Skipped unless GINKGO_TOUR=1, so CI never runs it;
/// `scripts/film-tour.sh <shot>` runs one on the iPhone.
///
/// Every tap and scene change prints a `TOUR` line (seconds from the shot's start, and the tap's
/// position as a fraction of the screen) so the editing script can cut on scenes and draw taps.
@MainActor
final class DemoTourUITests: XCTestCase {
    private var start = Date()
    private var app = XCUIApplication()
    private var any: XCUIElementQuery { app.descendants(matching: .any) }

    override func setUp() async throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["GINKGO_TOUR"] == "1", "Filming only: run with scripts/film-tour.sh")
        XCUIDevice.shared.appearance = env["TOUR_DARK"] == "1" ? .dark : .light
    }

    // MARK: Shots

    /// The whole real chain on the found furniture: snap, walk around, parts, ideas, the planner
    /// checking every step, the proof, the transform and AR.
    func testChain() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The walk-around needs the LiDAR iPhone")
        #else
        launch([])
        mark("home")
        hold(2.5)
        tap(app.buttons["snapFurniture"], "snapFurniture")
        wait(app.buttons["capture"], "Scan screen")
        mark("scan")
        hold(1.5)
        tap(app.buttons["walkAroundLink"], "walkAround")
        let progress = any["walkAroundProgress"]
        wait(progress, "walk-around progress")
        mark("walkAround")
        // The person holding the phone walks around the furniture; the app says when it's covered.
        let walkLimit = seconds("TOUR_WALK_MAX", 90)
        let ready = NSPredicate(format: "label CONTAINS 'Ready'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: ready, evaluatedWith: progress)], timeout: walkLimit),
                       .completed, "The walk-around wasn't covered within \(Int(walkLimit)) s")
        mark("walkReady")
        hold(seconds("TOUR_AIM_SECONDS", 3))  // time to aim the dot at the furniture
        tap(app.buttons["walkAroundButton"], "done")
        guard any["walkAroundResult"].waitForExistence(timeout: 10) else {
            let said = any["walkAroundInstruction"].label
            return XCTFail("No measurement. The app said: \(said)")
        }
        mark("measured")
        hold(3)
        tap(app.buttons["makePlan"], "makePlan")
        wait(app.buttons["planFromParts"], "parts", timeout: 45)
        mark("parts")
        hold(3)
        slowScroll(until: app.buttons["planFromParts"])
        tap(app.buttons["planFromParts"], "seeIdeas")
        wait(app.buttons["idea-bench"], "ideas")
        mark("ideas")
        hold(3)
        tap(app.buttons["idea-bench"], "bench")
        wait(app.buttons["seeProof"], "planner", timeout: 90)
        mark("planned")
        hold(3.5)
        slowScroll(until: app.buttons["seeProof"])
        tap(app.buttons["seeProof"], "seeProof")
        proofAndBuild()
        #endif
    }

    /// From the proven sample plan: the proof, then the transform and AR. A re-shoot of the
    /// chain's last half when the live run's Gemini plan isn't the one to show.
    func testProof() {
        launch(["-openScreen", "example"])
        proofAndBuild()
    }

    /// The same furniture, a chatbot's plan versus Ginkgo's, judged by the same validator.
    func testContrast() {
        launch(["-openScreen", "contrast"])
        wait(any["verdict"], "chatbot verdict")
        mark("chatbot")
        hold(3)
        slowScroll(times: 2)
        hold(1.5)
        tap(app.buttons["Ginkgo"], "ginkgoSide")
        XCTAssertTrue(any["verdict"].label.contains("Proven"), any["verdict"].label)
        mark("ginkgo")
        hold(3)
        slowScroll(times: 2)
        hold(2)
    }

    /// Verify before cutting: the tape-measure check of each dimension the plan depends on.
    func testVerify() {
        launch(["-openScreen", "example"])
        wait(any["verdict"], "proof")
        hold(1)
        slowScroll(until: app.buttons["verify"])
        tap(app.buttons["verify"], "verify")
        wait(any["verifyStatus"], "verify")
        mark("verify")
        hold(3)
        slowScroll(times: 2)
        hold(2)
    }

    // MARK: Shared scenes

    private func proofAndBuild() {
        wait(any["verdict"], "proof")
        XCTAssertTrue(any["verdict"].label.contains("Proven"), "The chain should reach a proven plan: \(any["verdict"].label)")
        mark("proof")
        hold(3)
        slowScroll(until: app.buttons["seeItBuilt"])
        hold(1.5)
        tap(app.buttons["seeItBuilt"], "seeItBuilt")
        wait(any["transformStage"], "transform")
        mark("old")
        hold(2.5)
        tap(app.buttons["transformButton"], "transform")
        mark("transformed")
        hold(4)
        tap(app.buttons["arButton"], "viewInAR")
        mark("ar")
        // AR Quick Look: the person aims at the floor and the build appears at true size.
        hold(seconds("TOUR_AR_SECONDS", 10))
        mark("end")
    }

    // MARK: Pacing and the log

    private func launch(_ args: [String]) {
        app = XCUIApplication()
        app.launchArguments = args
        app.launchSkippingFirstRun()
        start = Date()
        log("START")
    }

    /// Waits until the element is on screen, then a short beat so a viewer's eye lands before the tap.
    private func tap(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(name) never appeared")
        XCTAssertTrue(element.isHittable, "\(name) is on screen but can't be tapped")
        hold(0.6)
        let frame = element.frame, screen = app.frame
        log(String(format: "TAP %@ x=%.3f y=%.3f", name, frame.midX / screen.width, frame.midY / screen.height))
        element.tap()
    }

    private func wait(_ element: XCUIElement, _ name: String, timeout: TimeInterval = 15) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(name) didn't appear within \(Int(timeout)) s")
    }

    /// Slow swipes, the way a person reads a screen, until the element can be tapped.
    private func slowScroll(until element: XCUIElement) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 8 {
            app.swipeUp(velocity: .slow)
            hold(0.8)
            swipes += 1
        }
    }

    private func slowScroll(times: Int) {
        for _ in 0..<times {
            app.swipeUp(velocity: .slow)
            hold(0.8)
        }
    }

    private func hold(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func mark(_ scene: String) { log("SCENE \(scene)") }

    private func log(_ event: String) {
        print(String(format: "TOUR %.2f %@", Date().timeIntervalSince(start), event))
    }

    private func seconds(_ key: String, _ fallback: TimeInterval) -> TimeInterval {
        ProcessInfo.processInfo.environment[key].flatMap(TimeInterval.init) ?? fallback
    }
}
