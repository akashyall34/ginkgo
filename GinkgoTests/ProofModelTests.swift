import GinkgoCore
import XCTest
@testable import Ginkgo

final class ProofModelTests: XCTestCase {
    private func proven() throws -> ProofModel { try XCTUnwrap(ProofModel.example()) }
    private func chatbot() throws -> ProofModel { try XCTUnwrap(ProofModel.example(chatbot: true)) }

    // MARK: verdict

    func testAPassingPlanIsProvenToFit() throws {
        let m = try proven()
        XCTAssertEqual(m.verdict, .proven)
        XCTAssertEqual(m.headline, "Proven to fit")
    }

    func testAFailingPlanCountsItsProblems() throws {
        let m = try chatbot()
        XCTAssertEqual(m.verdict, .fails(problems: 4))
        XCTAssertEqual(m.headline, "Doesn't fit: 4 problems")
    }

    func testOneProblemIsSingular() throws {
        let m = try chatbot()
        let one = ProofModel(plan: m.plan, result: try result(m.result, violations: Array(m.result.violations.prefix(1))),
                             inventory: m.inventory)
        XCTAssertEqual(one.headline, "Doesn't fit: 1 problem")
    }

    func testPassesFlagWithViolationsStillFails() throws {
        // Defensive: never show "Proven" while any violation exists.
        let m = try chatbot()
        let contradictory = ProofModel(plan: m.plan, result: try result(m.result, passes: true), inventory: m.inventory)
        XCTAssertEqual(contradictory.verdict, .fails(problems: 4))
    }

    // MARK: cuts

    func testEachPlannedPieceGetsARowWithSizeAndSource() throws {
        let rows = try proven().cuts
        XCTAssertEqual(rows.map(\.name), ["Seat", "Left leg", "Right leg"])
        XCTAssertEqual(rows[0].size, "40.0 × 30.0 cm")
        XCTAssertEqual(rows[0].source, "From the top")
        XCTAssertEqual(rows[1].source, "From the left side")
        XCTAssertTrue(rows.allSatisfy(\.fits))
    }

    func testProblemsAttachToThePieceTheyAreAbout() throws {
        let rows = try chatbot().cuts
        // Vivek's validator on the chatbot plan: one problem on each of the four pieces.
        XCTAssertEqual(rows.map(\.name), ["Seat", "Left leg", "Right leg", "Shelf"])
        XCTAssertEqual(rows.map(\.problems.count), [1, 1, 1, 1])
        XCTAssertFalse(rows.contains(where: \.fits))
        let leftLeg = try XCTUnwrap(rows.first { $0.name == "Left leg" })
        XCTAssertTrue(leftLeg.problems[0].contains("388 × 458"), leftLeg.problems[0])
    }

    func testProblemsNotAboutAPlannedPieceAreStillShown() throws {
        let m = try proven()
        let overall = try JSONDecoder().decode(Violation.self, from: Data(
            #"{"code":"too_large","new_part":"whole bench","message":"The bench is 52 cm tall; you asked for under 50 cm."}"#.utf8))
        let withOverall = ProofModel(plan: m.plan, result: try result(m.result, passes: false, violations: [overall]),
                                     inventory: m.inventory)
        XCTAssertEqual(withOverall.otherProblems, ["The bench is 52 cm tall; you asked for under 50 cm."])
        XCTAssertTrue(withOverall.cuts.allSatisfy(\.fits))
    }

    // MARK: sag

    func testSagRowsShowShareOfTheLimit() throws {
        let seat = try XCTUnwrap(try proven().sagRows.first)
        XCTAssertEqual(seat.name, "Seat")
        // Vivek's validator: 0.386 mm of the 0.60 mm allowed.
        XCTAssertEqual(seat.shareOfLimit, 0.6436, accuracy: 1e-4)
        XCTAssertEqual(seat.summary, "0.39 of 0.60 mm allowed")
        XCTAssertTrue(seat.passes)
        // The chatbot's mistakes are fit, screw holes and a damaged part, not bending.
        let chatbotSag = try chatbot().sagRows
        XCTAssertFalse(chatbotSag.isEmpty)
        XCTAssertTrue(chatbotSag.allSatisfy(\.passes))
    }

    func testAZeroLimitNeverReadsAsSafe() {
        let row = ProofModel.SagRow(name: "Shelf", deflectionMm: 0.1, limitMm: 0, passes: false)
        XCTAssertEqual(row.shareOfLimit, .infinity)
    }

    // MARK: cutting diagram and checks

    func testSheetsFollowInventoryOrderAndSkipUnusedPanels() throws {
        let sheets = try proven().sheets
        XCTAssertEqual(sheets.map(\.name), ["Top", "Left side", "Right side"], "The damaged drawer front is unused")
        XCTAssertEqual(sheets[0].cuts.map(\.newPart), ["seat"])
        XCTAssertEqual(sheets[0].part.keepOuts.count, 2, "Screw holes come along for the diagram")
    }

    func testChecksAreTightestFirst() throws {
        XCTAssertEqual(try proven().checksBeforeCutting, [
            "Check the top's width: 52 mm to spare.",
            "Check the top's height: 62 mm to spare.",
            "Check the left side's width: 72 mm to spare.",
        ])
    }

    func testReuseText() throws {
        XCTAssertEqual(try proven().reuse, "52% of the wood reused")
        XCTAssertEqual(try chatbot().reuse, "85% of the wood reused", "Vivek's validator: 84.9%")
    }

    // MARK: names and loading

    func testDisplayNames() {
        XCTAssertEqual(ProofModel.displayName("side_left"), "Left side")
        XCTAssertEqual(ProofModel.displayName("leg_right"), "Right leg")
        XCTAssertEqual(ProofModel.displayName("drawer_front"), "Drawer front")
        XCTAssertEqual(ProofModel.displayName("top"), "Top")
        XCTAssertEqual(ProofModel.displayName("left"), "Left", "A lone side word stays put")
    }

    func testExampleIsMissingFromABundleWithoutTheFiles() {
        XCTAssertNil(ProofModel.example(bundle: Bundle(for: ProofModelTests.self)))
    }

    // MARK: helpers

    /// A copy of a validation result with some fields replaced, via its JSON.
    private func result(_ base: ValidationResult, passes: Bool? = nil,
                        violations: [Violation]? = nil) throws -> ValidationResult {
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
        if let passes { json["passes"] = passes }
        if let violations {
            json["violations"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(violations))
        }
        return try JSONDecoder().decode(ValidationResult.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
