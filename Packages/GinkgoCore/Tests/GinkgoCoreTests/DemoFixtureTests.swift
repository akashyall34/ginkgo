import Foundation
@testable import GinkgoCore
import XCTest

/// The files demo mode replays offline: real Gemini readings of the team's three props and one recorded agent run.
/// If any of them stops making sense to the current validator, CI fails before the demo does.
final class DemoFixtureTests: XCTestCase {
    private func props() throws -> [(name: String, inventory: Inventory)] {
        try ["stool", "drawer_cart", "box"].map { name in
            (name, try JSONDecoder().decode(Inventory.self, from: Fixtures.data("props/\(name).json")))
        }
    }

    func testEveryPropGetsASafePlanOrAnHonestNo() throws {
        for (name, inventory) in try props() {
            XCTAssertFalse(inventory.parts.isEmpty, name)
            if let result = RuleBasedPlanner.bench(inventory: inventory) {
                XCTAssertTrue(result.validation.passes, "\(name): the fallback only returns validated plans")
            }
        }
    }

    func testNonWoodPropsAreNeverCut() throws {
        for (name, inventory) in try props() where name != "stool" {
            XCTAssertTrue(inventory.parts.allSatisfy { !$0.material.canBeCut }, "\(name) is plastic or cardboard")
            let plan = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory)).plan
            XCTAssertEqual(plan.template, .noCut, "\(name) is reused whole")
        }
    }

    func testTheRecordedDemoRunIsStillValid() throws {
        let record = try JSON.parse(Fixtures.data("demo_trace.json"))
        XCTAssertEqual(record["outcome"], "accepted")
        let trace = try XCTUnwrap(record["trace"]).decode([AgentStep].self)
        XCTAssertTrue(trace.contains { $0.status == .fail }, "the demo shows Gemini failing a check")
        XCTAssertEqual(trace.last?.status, .accepted, "and then being accepted")
        let plan = try XCTUnwrap(record["plan"]).decode(Plan.self)
        XCTAssertTrue(Validator.validate(plan: plan, inventory: try Fixtures.inventory(), limits: nil).passes,
                      "today's validator still accepts the recorded plan")
    }
}
