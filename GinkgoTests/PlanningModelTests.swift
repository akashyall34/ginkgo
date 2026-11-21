import FirebaseAILogic
import GinkgoCore
import XCTest
@testable import Ginkgo

/// A stand-in for Gemini that replies with scripted turns.
private actor ScriptedSession: AgentSession {
    private var replies: [ModelTurn]
    init(_ replies: [ModelTurn]) { self.replies = replies }
    func send(text: String) async throws -> ModelTurn { next() }
    func send(results: [ToolResult]) async throws -> ModelTurn { next() }
    private func next() -> ModelTurn { replies.isEmpty ? ModelTurn(calls: [], text: "done") : replies.removeFirst() }
}

private struct ScriptedModel: AgentModel {
    let replies: [ModelTurn]
    var failToStart = false
    struct Unreachable: Error {}
    func startSession(system: String, tools: [ToolSpec]) async throws -> any AgentSession {
        if failToStart { throw Unreachable() }
        return ScriptedSession(replies)
    }
}

@MainActor
final class PlanningModelTests: XCTestCase {
    private func inventory() throws -> Inventory {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        return try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    }

    /// Gemini submitting a bench that fits the sample parts: seat from the top, legs from the sides.
    private var submitBench: ModelTurn {
        func part(_ name: String, _ source: String, _ width: Double, _ height: Double, _ role: String,
                  span: Double? = nil) -> GinkgoCore.JSON {
            var fields: [String: GinkgoCore.JSON] = ["name": .string(name), "source_part_id": .string(source),
                                                     "width_mm": .number(width), "height_mm": .number(height),
                                                     "role": .string(role)]
            if let span { fields["span_mm"] = .number(span) }
            return .object(fields)
        }
        let plan: GinkgoCore.JSON = .object([
            "template": .string("bench"),
            "new_parts": .array([part("seat", "top", 400, 300, "seat", span: 362),
                                 part("leg_left", "side_left", 300, 380, "support"),
                                 part("leg_right", "side_right", 300, 380, "support")]),
            "steps": .array([.string("Cut the seat."), .string("Cut the legs."), .string("Screw them together.")]),
            "hardware": .array([.object(["item": .string("wood screw, 40 mm"), "quantity": .number(8)])]),
        ])
        return ModelTurn(calls: [ToolCall(name: "submit_plan", args: .object(["reason": .string("A simple bench."), "plan": plan]))])
    }

    func testAPlanGeminiProposesAndTheValidatorAcceptsGoesToProof() async throws {
        let model = PlanningModel(inventory: try inventory())
        XCTAssertTrue(model.isRunning)
        await model.run(model: ScriptedModel(replies: [submitBench]))
        guard case .accepted = model.outcome else { return XCTFail("\(String(describing: model.outcome))") }
        XCTAssertEqual(model.headline, "Gemini's plan passed every check")
        XCTAssertNil(model.fallbackReason)
        XCTAssertFalse(model.steps.isEmpty, "The trace shows what was checked")
        let proof = try XCTUnwrap(model.proof)
        XCTAssertEqual(proof.verdict, .proven)
        XCTAssertEqual(proof.plan.newParts.map(\.name), ["seat", "leg_left", "leg_right"])
    }

    func testWhenGeminiIsUnreachableTheRuleBasedPlanTakesOver() async throws {
        let model = PlanningModel(inventory: try inventory())
        await model.run(model: ScriptedModel(replies: [], failToStart: true))
        guard case .fallback = model.outcome else { return XCTFail("\(String(describing: model.outcome))") }
        XCTAssertEqual(model.headline, "Gemini's plan didn't pass, so Ginkgo made its own safe plan")
        XCTAssertFalse(model.fallbackReason?.isEmpty ?? true)
        XCTAssertEqual(try XCTUnwrap(model.proof).verdict, .proven, "The fallback is always a proven plan")
    }

    func testNoUsablePartsMeansNoPlan() async throws {
        let damaged = try inventory().with(parts: try inventory().parts.map { $0.with(damaged: true) })
        let model = PlanningModel(inventory: damaged)
        await model.run(model: ScriptedModel(replies: [], failToStart: true))
        XCTAssertEqual(model.headline, "No safe plan can be made from these parts")
        XCTAssertNil(model.proof)
    }
}

final class AgentBridgeTests: XCTestCase {
    func testJSONSurvivesTheTripThroughFirebaseUnchanged() {
        let json: GinkgoCore.JSON = .object(["a": .array([.null, .bool(true), .number(1.5), .string("x")]),
                                             "b": .object(["c": .number(-2)])])
        XCTAssertEqual(AgentBridge.ginkgo(AgentBridge.firebase(json)), json)
    }

    func testAToolResultIsAlwaysAnObject() {
        XCTAssertEqual(AgentBridge.object(.object(["ok": .bool(true)])).keys.sorted(), ["ok"])
        XCTAssertEqual(AgentBridge.object(.string("fine")).keys.sorted(), ["result"])
    }

    func testEachToolKeepsItsRequiredAndOptionalParameters() {
        for spec in AgentTools.all {
            let parameters = AgentBridge.parameters(of: spec)
            guard case .object(let properties, _) = spec.parameters else { return XCTFail(spec.name) }
            XCTAssertEqual(Set(parameters.properties.keys), Set(properties.map(\.name)), spec.name)
            XCTAssertEqual(Set(parameters.optional), Set(properties.filter { !$0.required }.map(\.name)), spec.name)
            _ = AgentBridge.declaration(spec)
        }
    }

    func testGeminisCallsBecomeToolCalls() {
        let turn = AgentBridge.turn([FunctionCallPart(name: "check_fit", args: ["reason": .string("Check it.")])], text: nil)
        XCTAssertEqual(turn.calls, [ToolCall(name: "check_fit", args: .object(["reason": .string("Check it.")]))])
        XCTAssertEqual(AgentBridge.turn([], text: "All done.").text, "All done.")
    }
}

final class PlanningWordingTests: XCTestCase {
    func testConnectionErrorsAreShownInPlainWords() {
        let raw = AgentStep(index: 2, reason: "Couldn't reach Gemini", status: .error,
                            summary: "internalError(underlying: FirebaseAILogic.BackendError(...))", tool: .fallback)
        XCTAssertEqual(PlanningView.summary(raw), "Gemini's connection failed, so Ginkgo planned it with its own rules.")
        let check = AgentStep(index: 0, reason: "Check it.", status: .pass, summary: "seat from top: fits, 12 mm to spare", tool: .checkFit)
        XCTAssertEqual(PlanningView.summary(check), "seat from top: fits, 12 mm to spare")
    }
}
