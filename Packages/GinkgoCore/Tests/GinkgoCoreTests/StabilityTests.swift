@testable import GinkgoCore
import XCTest

/// A bench on skinny supports passes fit and sag but tips over. Supports must be boards at least 150 mm wide.
final class StabilityTests: XCTestCase {
    private func benchDraft(supportWidth: Double) throws -> PlanDraft {
        let draft = try Fixtures.benchDraft()
        let parts = draft.newParts.map { part in
            part.role != .support ? part : DraftPart(heightMm: part.heightMm, name: part.name, role: .support,
                                                     sourcePartID: part.sourcePartID, spanMm: nil, widthMm: supportWidth)
        }
        return PlanDraft(hardware: draft.hardware, newParts: parts, steps: draft.steps, template: draft.template)
    }

    private func validate(supportWidth: Double, template: Template? = nil) throws -> ValidationResult {
        var draft = try benchDraft(supportWidth: supportWidth)
        if let template { draft = PlanDraft(hardware: draft.hardware, newParts: draft.newParts, steps: draft.steps, template: template) }
        let inventory = try Fixtures.inventory()
        return Validator.validate(plan: Layout.plan(from: draft, inventory: inventory, id: "p"), inventory: inventory, limits: nil)
    }

    /// The stool prop, as the parts reader would see it: a padded seat board, rails and curved legs, all solid wood.
    private var stool: Inventory {
        func part(_ id: String, _ type: TypeEnum, _ size: [Double], _ thickness: Double) -> Part {
            Part(damaged: false, heightMm: size[1], id: id, keepOuts: [], material: .solidWood, thicknessMm: thickness,
                 type: type, widthMm: size[0])
        }
        return Inventory(parts: [
            part("top", .top, [420, 330], 18),
            part("rail_1", .rail, [380, 70], 18), part("rail_2", .rail, [290, 70], 18),
            part("leg_1", .leg, [45, 430], 45), part("leg_2", .leg, [45, 430], 45),
            part("leg_3", .leg, [45, 430], 45), part("leg_4", .leg, [45, 430], 45),
        ], scanID: "scan-stool")
    }

    func testTheSampleBenchStandsFirm() throws {
        XCTAssertTrue(try validate(supportWidth: 300).passes)
    }

    func testBoundaryIs150Millimetres() throws {
        XCTAssertTrue(try validate(supportWidth: 150).passes, "exactly 150 mm is enough")
        let narrow = try validate(supportWidth: 149)
        XCTAssertEqual(narrow.violations.map(\.code), [.unstable, .unstable])
        XCTAssertEqual(narrow.violations.first?.message,
                       "leg_left: only 149 mm wide, so the build would tip over. Supports must be flat boards at least 150 mm wide.")
    }

    func testNoCutPlansHaveNoSupportsToCheck() throws {
        XCTAssertFalse(try validate(supportWidth: 40, template: .noCut).violations.contains { $0.code == .unstable })
    }

    func testTheStoolNeverGetsABenchOnSkinnyLegs() throws {
        let (plan, validation) = try XCTUnwrap(RuleBasedPlanner.bench(inventory: stool))
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .noCut, "an honest reuse-as-is plan, not a wobbly bench")
    }

    func testTheAgentCannotSubmitSkinnySupports() throws {
        let draft = try JSON.from(benchDraft(supportWidth: 37))
        let outcome = ToolExecutor(inventory: try Fixtures.inventory(), limits: nil)
            .run(ToolCall(name: "submit_plan", args: ["reason": "Use leg strips.", "plan": draft]), index: 0)
        XCTAssertNil(outcome.accepted)
        XCTAssertEqual(outcome.step.summary.hasPrefix("rejected, 2 problems: leg_left: only 37 mm wide"), true)
    }

    func testThePromptsTellGeminiTheRules() {
        XCTAssertTrue(Prompts.plannerSystem.contains("at least 150 mm wide"))
        for info in MaterialCatalog.all {
            XCTAssertTrue(Prompts.plannerSystem.contains("- \(info.material.rawValue): "), "\(info.material) is in the system prompt")
            XCTAssertTrue(PartsReader.prompt.contains(info.material.rawValue), "\(info.material) is in the parts prompt")
        }
        XCTAssertTrue(Prompts.plannerSystem.contains("- plastic: never cut, reuse whole (has thin walls that crack or warp when sawn)"))
    }

    func testCatalogIsTheSingleSourceOfTruth() {
        XCTAssertEqual(MaterialCatalog.all.count, 5)
        XCTAssertEqual(Set(MaterialCatalog.all.map(\.material)).count, 5, "one row per material")
        for info in MaterialCatalog.all {
            XCTAssertEqual(Sag.stiffness(of: info.material), info.stiffness)
            XCTAssertFalse(info.source.isEmpty, "every stiffness value names its source")
            XCTAssertEqual(MaterialCatalog.info(info.material), info)
        }
        XCTAssertEqual(MaterialCatalog.fastener(for: [.solidWood, .plastic]), "cable tie, 200 mm", "the weakest decides")
        XCTAssertEqual(MaterialCatalog.fastener(for: []), "wood screw, 40 mm")
    }
}
