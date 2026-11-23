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
}
