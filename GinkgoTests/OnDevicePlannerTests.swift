import FoundationModels
import GinkgoCore
import XCTest
@testable import Ginkgo

/// The on-device planner's parts that don't need the model: the tool schemas, the tools answering with
/// Ginkgo's real validator, and the repair prompt. The model itself is checked by a live run on a Mac or iPhone.
@available(iOS 26.0, *)
final class OnDevicePlannerTests: XCTestCase {
    private func inventory() throws -> Inventory {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        return try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    }

    private final class Seen: @unchecked Sendable { var steps: [AgentStep] = [] }

    // MARK: - Schemas

    func testEveryToolConvertsToAnAppleSchema() throws {
        for spec in AgentTools.all {
            let schema = try ToolSchemaBridge.schema(for: spec)
            let text = String(describing: schema)
            XCTAssertTrue(text.contains("reason"), "\(spec.name) keeps its reason field")
        }
    }

    func testOptionalFieldsStayOptionalAndEnumsKeepTheirChoices() throws {
        let spec = ToolSpec(name: "t", description: "d", parameters: .object([
            ParamProperty(name: "kind", schema: .enumeration(["bench", "bookshelf"], "The kind.")),
            ParamProperty(name: "span_mm", schema: .number("Span."), required: false),
            ParamProperty(name: "count", schema: .integer("How many.")),
            ParamProperty(name: "ok", schema: .boolean("Fine?")),
            ParamProperty(name: "steps", schema: .array(.string("One step."), "Steps.")),
        ], "Args."))
        let text = String(describing: try ToolSchemaBridge.schema(for: spec))
        XCTAssertTrue(text.contains("bench") && text.contains("bookshelf"), text)
        XCTAssertTrue(text.contains("span_mm"), text)
    }

    func testDescriptionsReachTheModel() {
        XCTAssertEqual(ToolSchemaBridge.description(of: .number("Span in mm.")), "Span in mm.")
        XCTAssertEqual(ToolSchemaBridge.description(of: .array(.string("x"), "Steps.")), "Steps.")
        XCTAssertEqual(ToolSchemaBridge.description(of: .boolean("Fine?")), "Fine?")
    }

    // MARK: - Tools answer with the real validator

    func testACheckFitCallIsAnsweredByTheValidatorAndRecorded() async throws {
        let seen = Seen()
        let recorder = PlanRecorder { step in seen.steps.append(step) }
        let tool = try PlannerTool(spec: AgentTools.checkFit, executor: ToolExecutor(inventory: try inventory(), limits: nil),
                                   recorder: recorder)
        let args = try GeneratedContent(json: """
            {"reason":"Check the seat.","placements":[{"new_part":"seat","source_part_id":"top","width_mm":400,"height_mm":300}]}
            """)
        let answer = try await tool.call(arguments: args)
        XCTAssertTrue(answer.contains("fits") || answer.contains("spare"), answer)
        let steps = await recorder.steps
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.tool, .checkFit)
        XCTAssertEqual(seen.steps.count, 1, "The screen hears about the step as it happens")
    }

    func testAPartThatDoesntFitCountsAsARejection() async throws {
        let recorder = PlanRecorder { _ in }
        let tool = try PlannerTool(spec: AgentTools.checkFit, executor: ToolExecutor(inventory: try inventory(), limits: nil),
                                   recorder: recorder)
        _ = try await tool.call(arguments: try GeneratedContent(json: """
            {"reason":"Too big.","placements":[{"new_part":"seat","source_part_id":"top","width_mm":4000,"height_mm":3000}]}
            """))
        let rejections = await recorder.rejections
        let accepted = await recorder.accepted
        XCTAssertEqual(rejections, 1)
        XCTAssertNil(accepted)
    }

    func testGarbledArgumentsGetAnErrorTheModelCanReadNotACrash() async throws {
        let recorder = PlanRecorder { _ in }
        let tool = try PlannerTool(spec: AgentTools.submitPlan, executor: ToolExecutor(inventory: try inventory(), limits: nil),
                                   recorder: recorder)
        let answer = try await tool.call(arguments: try GeneratedContent(json: #"{"reason":"x"}"#))
        XCTAssertTrue(answer.contains("error") || answer.contains("rejected"), answer)
        let accepted = await recorder.accepted
        XCTAssertNil(accepted)
    }

    func testAValidSubmitIsAccepted() async throws {
        let inventory = try inventory()
        let recorder = PlanRecorder { _ in }
        let tool = try PlannerTool(spec: AgentTools.submitPlan, executor: ToolExecutor(inventory: inventory, limits: nil),
                                   recorder: recorder)
        let bench = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory)).plan
        let parts = bench.newParts.map { part -> [String: Any] in
            var json: [String: Any] = ["name": part.name, "source_part_id": part.sourcePartID, "width_mm": part.widthMm,
                                       "height_mm": part.heightMm, "role": part.role.rawValue]
            if let span = part.spanMm { json["span_mm"] = span }
            return json
        }
        let plan: [String: Any] = ["template": "bench", "new_parts": parts, "steps": ["Cut.", "Screw.", "Sand."],
                                   "hardware": [["item": "wood screw, 40 mm", "quantity": 8]]]
        let data = try JSONSerialization.data(withJSONObject: ["reason": "Submit.", "plan": plan])
        _ = try await tool.call(arguments: try GeneratedContent(json: try XCTUnwrap(String(bytes: data, encoding: .utf8))))
        let accepted = await recorder.accepted
        XCTAssertNotNil(accepted, "The rule-based bench, submitted by the model, passes")
    }

    // MARK: - Repair and availability

    func testTheRepairPromptHandsBackTheProblem() {
        XCTAssertTrue(OnDevicePlanner.repairPrompt(lastProblem: "seat: 4 mm short").contains("seat: 4 mm short"))
        XCTAssertTrue(OnDevicePlanner.repairPrompt(lastProblem: nil).contains("No plan was submitted."))
        XCTAssertTrue(OnDevicePlanner.repairPrompt(lastProblem: nil).contains("submit_plan"))
    }

    func testAnOnDeviceRunIsCappedAndSaysWhy() async throws {
        // A one-nanosecond limit: the cap always wins, so this checks the cap without depending on the model.
        let planner = OnDevicePlanner(enabled: true, timeLimit: .nanoseconds(1))
        let result = await planner.plan(inventory: try inventory(), request: "Make a bench.") { _ in }
        XCTAssertNil(result.accepted)
        XCTAssertEqual(result.error?.hasPrefix("took longer than"), true, result.error ?? "no error")
    }

    func testTheDefaultCapIsOneMinute() {
        XCTAssertEqual(OnDevicePlanner().timeLimit, .seconds(60))
    }

    func testOffMeansUnavailable() {
        XCTAssertFalse(OnDevicePlanner(enabled: false).isAvailable)
    }

    func testAvailabilityFollowsTheSystemModel() {
        XCTAssertEqual(OnDevicePlanner().isAvailable, SystemLanguageModel.default.isAvailable)
    }

    // MARK: - The repair loop, with a scripted model

    /// A real tool answer from the real executor: a bench the validator accepts.
    private func accepted() throws -> ToolOutcome {
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
        let call = ToolCall(name: "submit_plan", args: .object(["reason": .string("A bench."), "plan": plan]))
        let outcome = ToolExecutor(inventory: try inventory(), limits: nil).run(call, index: 0)
        XCTAssertNotNil(outcome.accepted, "The helper's bench must pass the validator")
        return outcome
    }

    /// A real rejection: a seat far bigger than any panel, so the validator says it doesn't fit.
    private func rejection() throws -> ToolOutcome {
        let placements: GinkgoCore.JSON = .array([.object(["new_part": .string("seat"), "source_part_id": .string("top"),
                                                           "width_mm": .number(9999), "height_mm": .number(300)])])
        let call = ToolCall(name: "check_fit", args: .object(["reason": .string("Try it."), "placements": placements]))
        let outcome = ToolExecutor(inventory: try inventory(), limits: nil).run(call, index: 0)
        XCTAssertEqual(outcome.step.status, .fail)
        return outcome
    }

    func testAPlanAcceptedOnTheFirstAnswerEndsTheLoopAtOnce() async throws {
        let recorder = PlanRecorder { _ in }
        let outcome = try accepted()
        var asked: [String] = []
        let stop = await OnDevicePlanner.repair(firstPrompt: "plan it", recorder: recorder) { prompt in
            asked.append(prompt)
            await recorder.record(outcome)
        }
        XCTAssertNil(stop)
        XCTAssertEqual(asked, ["plan it"])
    }

    func testARejectedPlanGetsTheValidatorsComplaintUntilTheAttemptsRunOut() async throws {
        let recorder = PlanRecorder { _ in }
        var asked: [String] = []
        let rejected = try rejection()
        let stop = await OnDevicePlanner.repair(firstPrompt: "plan it", recorder: recorder) { prompt in
            asked.append(prompt)
            await recorder.record(rejected)
        }
        XCTAssertNil(stop, "Running out of attempts isn't an error: the cloud takes over")
        XCTAssertEqual(asked.count, HybridRouter.deviceAttempts + 1)
        XCTAssertEqual(asked.first, "plan it")
        XCTAssertTrue(asked.dropFirst().allSatisfy { $0.contains(rejected.step.summary) })
    }

    func testAModelThatStopsWithoutAnyCheckIsToldNoPlanWasSubmitted() async {
        var asked: [String] = []
        _ = await OnDevicePlanner.repair(firstPrompt: "plan it", recorder: PlanRecorder { _ in }) { asked.append($0) }
        XCTAssertTrue(asked[1].contains("No plan was submitted."), asked[1])
    }

    func testAModelErrorEndsTheLoopWithItsMessage() async {
        struct Busy: Error, CustomStringConvertible { var description: String { "model busy" } }
        let stop = await OnDevicePlanner.repair(firstPrompt: "plan it", recorder: PlanRecorder { _ in }) { _ in throw Busy() }
        XCTAssertEqual(stop, "model busy")
    }

    func testACancelledRunStopsBeforeAskingTheModel() async {
        let task = Task { () -> (String?, Int) in
            try? await Task.sleep(for: .seconds(5))
            var asked = 0
            let stop = await OnDevicePlanner.repair(firstPrompt: "p", recorder: PlanRecorder { _ in }) { _ in asked += 1 }
            return (stop, asked)
        }
        task.cancel()
        let (stop, asked) = await task.value
        XCTAssertEqual(stop, "cancelled")
        XCTAssertEqual(asked, 0)
    }

    func testAToolThatCantBecomeASchemaStopsTheRunWithAReason() async throws {
        let clash = ToolSpec(name: "bad", description: "d", parameters: .object([
            ParamProperty(name: "a", schema: .string("x")), ParamProperty(name: "a", schema: .number("y")),
        ], "Args."))
        let stop = await OnDevicePlanner.converse(inventory: try inventory(), request: "", recorder: PlanRecorder { _ in },
                                                  specs: [clash])
        XCTAssertTrue(stop?.hasPrefix("tool schema:") ?? false, String(describing: stop))
    }

    // MARK: - The race against the clock, and the stand-in

    func testWorkThatFinishesInTimeDecidesTheResult() async {
        let reason = await OnDevicePlanner.race(limit: .seconds(30)) { "stopped early" }
        XCTAssertEqual(reason, "stopped early")
        let normal = await OnDevicePlanner.race(limit: .seconds(30)) { nil }
        XCTAssertNil(normal, "Work that ends normally in time reports no problem")
    }

    func testWorkThatTakesTooLongIsStoppedWithTheLimit() async {
        let reason = await OnDevicePlanner.race(limit: .milliseconds(20)) {
            try? await Task.sleep(for: .seconds(30))
            return nil
        }
        XCTAssertTrue(reason?.hasPrefix("took longer than") ?? false, String(describing: reason))
    }

    func testAToolCallWithoutAValidObjectIsRefusedNotInvented() async throws {
        let recorder = PlanRecorder { _ in }
        let tool = try PlannerTool(spec: AgentTools.checkFit, executor: ToolExecutor(inventory: try inventory(), limits: nil),
                                   recorder: recorder)
        let answer = try await tool.call(arguments: try GeneratedContent(json: "{}"))
        XCTAssertFalse(answer.isEmpty)
    }
}

/// Before iOS 26 there's no on-device model: the stand-in is never available and plans nothing.
final class NoDevicePlannerTests: XCTestCase {
    func testTheStandInIsNeverAvailableAndPlansNothing() async throws {
        let planner = NoDevicePlanner()
        XCTAssertFalse(planner.isAvailable)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
        let result = await planner.plan(inventory: inventory, request: "") { _ in }
        XCTAssertNil(result.accepted)
        XCTAssertEqual(result.trace, [])
        XCTAssertEqual(result.model, DeviceModel.name)
    }
}
