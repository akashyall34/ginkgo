import GinkgoCore
import XCTest
@testable import Ginkgo

/// The Plan screens' wording, checked on the exact lines of the recorded Gemini run.
final class StepWordingTests: XCTestCase {
    private func step(_ tool: Tool, _ status: Status, _ summary: String) -> AgentStep {
        AgentStep(index: 0, reason: "Gemini's own reason", status: status, summary: summary, tool: tool)
    }

    private let failedFit = "seat from side_left: fits, 0 mm to spare; support_left from side_right: 8 mm short; "
        + "support_right from top: blocked by screw holes or damage"
    private let passedFit = "seat from top: fits, 12 mm to spare; support_left from side_left: fits, 22 mm to spare; "
        + "support_right from side_right: fits, 22 mm to spare"

    // MARK: - Headlines

    func testAFailedFitCountsOnlyTheCutsThatDontFit() {
        XCTAssertEqual(StepWording.headline(step(.checkFit, .fail, failedFit)), "2 of 3 cuts don't fit")
    }

    func testAPassedFitIsOneShortLine() {
        XCTAssertEqual(StepWording.headline(step(.checkFit, .pass, passedFit)), "All 3 cuts fit")
        XCTAssertEqual(StepWording.headline(step(.checkFit, .pass, "seat from top: fits, 12 mm to spare")), "The cut fits")
        XCTAssertEqual(StepWording.headline(step(.checkFit, .fail, "seat from top: 4 mm short")), "The cut doesn't fit")
    }

    func testSag() {
        XCTAssertEqual(StepWording.headline(step(.checkSag, .fail, "seat: bends 0.93 of 0.87 mm allowed, too much")), "Too bendy")
        XCTAssertEqual(StepWording.headline(step(.checkSag, .pass, "seat: bends 0.45 of 0.67 mm allowed")), "Strong enough")
    }

    func testSubmit() {
        XCTAssertEqual(StepWording.headline(step(.submitPlan, .accepted, "accepted by the validator: 3 parts, 64.9% reused")),
                       "Plan accepted: 3 parts, 64.9% reused")
        XCTAssertEqual(StepWording.headline(step(.submitPlan, .accepted, "accepted")), "Plan accepted")
        XCTAssertEqual(StepWording.headline(step(.submitPlan, .fail, "seat: 4 mm short")), "Plan sent back for another try")
    }

    func testFallbackNeverShowsRawErrorText() {
        let error = step(.fallback, .error, "internalError(underlying: FirebaseAILogic.BackendError(...))")
        XCTAssertEqual(StepWording.headline(error), "Gemini's connection failed, so Ginkgo planned it with its own rules.")
        let info = step(.fallback, .info, "notConfigured. Showing the rule-based bench instead; it passes the validator.")
        XCTAssertEqual(StepWording.headline(info), "Showing Ginkgo's own rule-based plan. It passes the validator.")
        XCTAssertEqual(StepWording.problems(info), [])
    }

    func testANoteKeepsItsOwnWords() {
        let note = step(.note, .info, "Gemini answered without using the tools; reminded it to check and submit.")
        XCTAssertEqual(StepWording.headline(note), note.summary)
        XCTAssertEqual(StepWording.problems(note), [])
    }

    // MARK: - Problem lines

    func testOnlyTheProblemsGetALineInPlainWords() {
        XCTAssertEqual(StepWording.problems(step(.checkFit, .fail, failedFit)), [
            "Left support from the right side: 8 mm short",
            "Right support from the top: blocked by screw holes or damage",
        ])
    }

    func testAPassingCheckHasNoLines() {
        XCTAssertEqual(StepWording.problems(step(.checkFit, .pass, passedFit)), [])
        XCTAssertEqual(StepWording.problems(step(.checkSag, .pass, "seat: bends 0.45 of 0.67 mm allowed")), [])
    }

    func testSagProblemInPlainWords() {
        XCTAssertEqual(StepWording.problems(step(.checkSag, .fail, "seat: bends 0.93 of 0.87 mm allowed, too much")),
                       ["Seat bends 0.93 mm; 0.87 mm allowed"])
    }

    func testARejectedSubmitShowsWhy() {
        XCTAssertEqual(StepWording.problems(step(.submitPlan, .fail, "seat: 4 mm short")), ["seat: 4 mm short"])
    }

    func testAnUnreadableLineIsShownAsItIs() {
        XCTAssertEqual(StepWording.item("something odd", tool: .checkFit), .init(text: "something odd", passes: false))
        XCTAssertEqual(StepWording.problems(step(.checkSag, .fail, "seat: no such part \"top\"")),
                       ["Seat: no such part \"top\""])
    }

    // MARK: - Names

    func testPieceAndPanelNames() {
        XCTAssertEqual(StepWording.piece("support_left"), "Left support")
        XCTAssertEqual(StepWording.piece("seat"), "Seat")
        XCTAssertEqual(StepWording.panel("side_right"), "right side")
        XCTAssertEqual(StepWording.panel("drawer_front"), "drawer front")
        XCTAssertEqual(StepWording.panel("left"), "left")
    }

    // MARK: - The run in one sentence

    func testTheStoryCountsTheProblemsCaught() {
        let trace = [step(.checkFit, .fail, failedFit), step(.checkSag, .fail, "seat: bends 0.93 of 0.87 mm allowed, too much"),
                     step(.checkFit, .fail, "seat from top: 4 mm short"), step(.checkFit, .pass, passedFit),
                     step(.submitPlan, .accepted, "accepted by the validator: 3 parts, 64.9% reused")]
        XCTAssertEqual(StepWording.story(trace), "Ginkgo's checks caught 3 problems before accepting a plan.")
    }

    func testTheStoryForOneOrNoProblems() {
        let accepted = step(.submitPlan, .accepted, "accepted")
        XCTAssertEqual(StepWording.story([step(.checkFit, .fail, "seat from top: 4 mm short"), accepted]),
                       "Ginkgo's checks caught 1 problem before accepting a plan.")
        XCTAssertEqual(StepWording.story([accepted]), "Gemini's first plan passed every check.")
    }

    func testNoStoryWithoutAnAcceptedPlan() {
        XCTAssertNil(StepWording.story([step(.checkFit, .fail, "seat from top: 4 mm short")]))
        XCTAssertNil(StepWording.story([]))
    }

    func testTheRecordedRunReadsCleanly() throws {
        let run = try XCTUnwrap(RecordedRun.load())
        for step in run.trace {
            let words = ([StepWording.headline(step)] + StepWording.problems(step)).joined(separator: " ")
            XCTAssertFalse(words.contains("_"), "Code names leak into: \(words)")
        }
        XCTAssertEqual(StepWording.story(run.trace), "Ginkgo's checks caught 3 problems before accepting a plan.")
    }
}
