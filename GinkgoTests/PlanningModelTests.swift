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

    func testAPlanMadeOnThisIPhoneSaysSo() async throws {
        let inventory = try inventory()
        let safe = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        let device = StubDevice(result: DevicePlanResult(accepted: AcceptedPlan(plan: safe.plan, validation: safe.validation),
                                                         trace: [], rejections: 0, model: "apple-on-device"))
        let planner = HybridPlanner(device: device, cloud: { _, _, _ in fatalError("The cloud isn't needed") },
                                    cloudModelName: "gemini")
        let model = PlanningModel(inventory: inventory)
        await model.run(planner: planner, online: false)
        XCTAssertEqual(model.route, Route(venue: .device, reason: .numbersOnDevice))
        XCTAssertEqual(model.headline, "Planned on this iPhone, and it passed every check")
        XCTAssertEqual(model.routing.map(\.venue), [.device])
        XCTAssertNotNil(model.proof)
    }

    // MARK: - Improve this plan

    private func onDevice(cloud: AgentOutcome) throws -> (PlanningModel, HybridPlanner) {
        let inventory = try inventory()
        let safe = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        let device = StubDevice(result: DevicePlanResult(accepted: AcceptedPlan(plan: safe.plan, validation: safe.validation),
                                                         trace: [], rejections: 0, model: "apple-on-device"))
        let planner = HybridPlanner(device: device, cloud: { _, _, _ in cloud }, cloudModelName: "gemini")
        return (PlanningModel(inventory: inventory), planner)
    }

    private func cloudPlan(reuse: Double) throws -> AgentOutcome {
        let safe = try XCTUnwrap(RuleBasedPlanner.bench(inventory: try inventory()))
        let validation = ValidationResult(passes: true, placements: safe.validation.placements, planID: safe.plan.id,
                                          reusePercent: reuse, sag: safe.validation.sag, verify: safe.validation.verify,
                                          violations: [])
        return .accepted(plan: safe.plan, validation: validation,
                         trace: [AgentStep(index: 0, reason: "", status: .accepted, summary: "accepted", tool: .submitPlan)])
    }

    func testImproveIsOfferedOnlyOnceTheNetworkIsBack() async throws {
        let (model, planner) = try onDevice(cloud: try cloudPlan(reuse: 99))
        await model.run(planner: planner, online: false)
        XCTAssertFalse(model.canImprove, "Offline there's nothing to improve with")
        model.online = true
        XCTAssertTrue(model.canImprove)
    }

    func testABetterCloudPlanShowsTheNewBadgeAndProof() async throws {
        let (model, planner) = try onDevice(cloud: try cloudPlan(reuse: 99))
        await model.run(planner: planner, online: false)
        model.online = true
        await model.improve(planner: planner)
        XCTAssertEqual(model.improvement?.choice, .improved)
        XCTAssertEqual(model.route, Route(venue: .cloud, reason: .improvedInCloud))
        XCTAssertEqual(model.proof?.result.reusePercent, 99)
        XCTAssertEqual(model.routing.map(\.task), [.planFromNumbers, .improvePlan])
        XCTAssertEqual(model.steps.map(\.index), Array(0..<model.steps.count), "Step numbers keep counting up")
        XCTAssertFalse(model.canImprove, "Offered once")
    }

    func testAWorseCloudPlanKeepsTheOnDeviceBadgeAndPlan() async throws {
        let (model, planner) = try onDevice(cloud: try cloudPlan(reuse: 1))
        await model.run(planner: planner, online: true)
        let before = model.proof?.result.reusePercent
        await model.improve(planner: planner)
        XCTAssertEqual(model.improvement?.choice, .original)
        XCTAssertEqual(model.route, Route(venue: .device, reason: .numbersOnDevice))
        XCTAssertEqual(model.proof?.result.reusePercent, before)
        XCTAssertFalse(model.canImprove, "Offered once, even when the first plan stays")
    }

    func testStepsFromTheDeviceAndTheCloudReachTheScreenAsTheyHappen() async throws {
        let inventory = try inventory()
        let safe = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        let live = AgentStep(index: 0, reason: "", status: .pass, summary: "seat fits", tool: .checkFit)
        let device = StepDevice(step: live, result: DevicePlanResult(
            accepted: AcceptedPlan(plan: safe.plan, validation: safe.validation), trace: [live], rejections: 0,
            model: "apple-on-device"))
        let better = try cloudPlan(reuse: 99)
        let planner = HybridPlanner(device: device, cloud: { _, _, onStep in
            onStep(live)
            return better
        }, cloudModelName: "gemini")
        let model = PlanningModel(inventory: inventory)
        await model.run(planner: planner, online: true)
        await Task.yield()
        XCTAssertNotNil(model.proof)
        model.online = true
        await model.improve(planner: planner)
        await Task.yield()
        XCTAssertEqual(model.improvement?.choice, .improved)
        XCTAssertFalse(model.steps.isEmpty)
    }

    func testWhileTheDevicePlansTheHeadlineSaysSo() throws {
        let model = PlanningModel(inventory: try inventory())
        XCTAssertEqual(model.headline, "Gemini is planning, and Ginkgo checks every step…", "Before any route is known")
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

private struct StubDevice: DevicePlanning {
    var isAvailable = true
    var result: DevicePlanResult
    func plan(inventory: Inventory, request: String, onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult {
        result
    }
}

/// A device that reports a step while it plans, as the real one does.
private struct StepDevice: DevicePlanning {
    var isAvailable = true
    var step: AgentStep
    var result: DevicePlanResult
    func plan(inventory: Inventory, request: String, onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult {
        onStep(step)
        return result
    }
}
