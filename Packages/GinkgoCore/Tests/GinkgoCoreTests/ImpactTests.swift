import XCTest
@testable import GinkgoCore

final class ImpactTests: XCTestCase {
    private func summary() throws -> ImpactSummary {
        let inventory = try Fixtures.inventory()
        let plan = try Fixtures.planBench()
        let validation = Validator.validate(plan: plan, inventory: inventory, limits: nil)
        return try XCTUnwrap(ImpactSummary(plan: plan, validation: validation, inventory: inventory))
    }

    // MARK: - EPA facts

    func testTheEPAFiguresMatchTheTable() {
        XCTAssertEqual(ImpactFacts.landfillShare, 80.1, "EPA states 80.1% landfilled")
        XCTAssertEqual(ImpactFacts.landfilledMillionTons, 9.7)
        XCTAssertEqual(ImpactFacts.year, 2018)
        XCTAssertEqual(ImpactFacts.sentence,
                       "In 2018 the US landfilled 9.7 million tons of furniture: 80.1% of what it generated.")
    }

    func testTheSourceIsEPAsOwnPage() {
        XCTAssertTrue(ImpactFacts.sourceURL.hasPrefix("https://www.epa.gov/"))
        XCTAssertNotNil(URL(string: ImpactFacts.sourceURL))
    }

    // MARK: - From the plan

    func testTheNumbersComeFromThePlanAndInventory() throws {
        let impact = try summary()
        let inventory = try Fixtures.inventory()
        let plan = try Fixtures.planBench()
        let total = inventory.parts.reduce(0) { $0 + $1.widthMm * $1.heightMm } / 1_000_000
        let used = plan.newParts.reduce(0) { $0 + $1.widthMm * $1.heightMm } / 1_000_000
        XCTAssertEqual(impact.totalAreaM2, total, accuracy: 1e-9)
        XCTAssertEqual(impact.reusedAreaM2, used, accuracy: 1e-9)
        XCTAssertEqual(impact.panelsTotal, inventory.parts.count)
        XCTAssertGreaterThan(impact.panelsUsed, 0)
        XCTAssertLessThanOrEqual(impact.panelsUsed, impact.panelsTotal)
        XCTAssertLessThanOrEqual(impact.reusedAreaM2, impact.totalAreaM2)
    }

    func testThePercentIsTheValidatorsOwnNumber() throws {
        let inventory = try Fixtures.inventory()
        let plan = try Fixtures.planBench()
        let validation = Validator.validate(plan: plan, inventory: inventory, limits: nil)
        let impact = try XCTUnwrap(ImpactSummary(plan: plan, validation: validation, inventory: inventory))
        XCTAssertEqual(impact.reusePercent, validation.reusePercent)
        XCTAssertEqual(impact.headline, String(format: "%.0f%% of the wood stays in use", validation.reusePercent))
    }

    func testTwoCutsFromOnePanelCountThePanelOnce() throws {
        let inventory = try Fixtures.inventory()
        let plan = try Fixtures.planBench()
        let cut = { (name: String, x: Double) in
            Placement(heightMm: 100, newPart: name, rotated: false, sourcePartID: "top", widthMm: 100, xMm: x, yMm: 0)
        }
        let validation = ValidationResult(passes: true, placements: [cut("a", 0), cut("b", 200)], planID: plan.id,
                                          reusePercent: 10, sag: [], verify: [], violations: [])
        let impact = try XCTUnwrap(ImpactSummary(plan: plan, validation: validation, inventory: inventory))
        XCTAssertEqual(impact.panelsUsed, 1, "Two cuts, one panel")
        XCTAssertEqual(impact.panelsLine, "1 of \(inventory.parts.count) panels used")
    }

    func testOnePanelPieceSaysPanelInTheSingular() throws {
        let one = Inventory(parts: [try XCTUnwrap(Fixtures.inventory().parts.first)], scanID: "s")
        let plan = try Fixtures.planBench()
        let validation = ValidationResult(passes: true, placements: [], planID: plan.id, reusePercent: 0, sag: [],
                                          verify: [], violations: [])
        let impact = try XCTUnwrap(ImpactSummary(plan: plan, validation: validation, inventory: one))
        XCTAssertEqual(impact.panelsLine, "0 of 1 panel used")
    }

    func testAPlanThatFailedTheValidatorMakesNoClaim() throws {
        let inventory = try Fixtures.inventory()
        let plan = try Fixtures.planChatbot()
        let validation = Validator.validate(plan: plan, inventory: inventory, limits: nil)
        XCTAssertFalse(validation.passes, "The chatbot's plan doesn't fit")
        XCTAssertNil(ImpactSummary(plan: plan, validation: validation, inventory: inventory))
    }

    func testTheLinesReadInPlainWords() throws {
        let impact = try summary()
        XCTAssertTrue(impact.areaLine.contains("m² of panel reused, out of"), impact.areaLine)
        XCTAssertTrue(impact.panelsLine.hasSuffix("panels used"), impact.panelsLine)
        XCTAssertTrue(ImpactSummary.note.contains("not weight"))
    }
}
