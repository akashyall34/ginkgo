@testable import GinkgoCore
import XCTest

final class ToolExecutorTests: XCTestCase {
    private func executor(_ inventory: Inventory? = nil, limits: SizeLimits? = nil) throws -> ToolExecutor {
        ToolExecutor(inventory: try inventory ?? Fixtures.inventory(), limits: limits)
    }

    private func fitItem(_ name: String, _ source: String, _ width: JSON, _ height: JSON) -> JSON {
        ["new_part": .string(name), "source_part_id": .string(source), "width_mm": width, "height_mm": height]
    }

    private func checkFit(_ items: [JSON], on executor: ToolExecutor? = nil) throws -> ToolOutcome {
        let call = ToolCall(name: "check_fit", args: ["reason": "Will the parts fit?", "placements": .array(items)])
        return try (executor ?? self.executor()).run(call, index: 3)
    }

    private func sagItem(_ name: String, _ source: String, _ role: String, span: JSON, depth: JSON) -> JSON {
        ["new_part": .string(name), "source_part_id": .string(source), "role": .string(role), "span_mm": span, "depth_mm": depth]
    }

    private func submit(_ plan: JSON, limits: SizeLimits? = nil) throws -> ToolOutcome {
        try executor(limits: limits).run(ToolCall(name: "submit_plan", args: ["reason": "Done.", "plan": plan]), index: 7)
    }

    private func errorText(_ outcome: ToolOutcome) -> String? {
        outcome.result.response["error"]?.stringValue
    }

    // MARK: - check_fit

    func testCheckFitAllPartsFit() throws {
        let outcome = try checkFit([fitItem("seat", "top", 400, 300), fitItem("leg_left", "side_left", 300, 380),
                                    fitItem("leg_right", "side_right", 300, 380)])
        XCTAssertEqual(outcome.step, AgentStep(
            index: 3, reason: "Will the parts fit?", status: .pass,
            summary: "seat from top: fits, 52 mm to spare; leg_left from side_left: fits, 72 mm to spare; "
                + "leg_right from side_right: fits, 72 mm to spare",
            tool: .checkFit))
        XCTAssertEqual(outcome.result.name, "check_fit")
        XCTAssertEqual(outcome.result.response["all_fit"], true)
        let first = outcome.result.response["results"]?.arrayValue?.first
        XCTAssertEqual(first?["spare_mm"], [52, 62])
        XCTAssertEqual(first?["fits"], true)
        XCTAssertNil(outcome.accepted)
    }

    func testCheckFitOneMillimetreShort() throws {
        let outcome = try checkFit([fitItem("seat", "top", 453, 300)])
        XCTAssertEqual(outcome.step.status, .fail)
        XCTAssertEqual(outcome.step.summary, "seat from top: 1 mm short")
        let row = outcome.result.response["results"]?.arrayValue?.first
        XCTAssertEqual(row?["blocked_by"], "too_big")
        XCTAssertEqual(row?["needed_mm"], [461, 308])
        XCTAssertEqual(row?["available_mm"], [460, 400])
        XCTAssertEqual(row?["short_by_mm"], 1)
        XCTAssertEqual(outcome.result.response["all_fit"], false)
    }

    func testCheckFitEveryKindOfBlock() throws {
        let outcome = try checkFit([
            fitItem("seat", "top", 452, 392), fitItem("front", "drawer_front", 100, 100), fitItem("ghost", "nope", 100, 100),
            fitItem("zero", "side_left", 0, 100), fitItem("a", "side_right", 300, 380), fitItem("b", "side_right", 300, 380),
        ])
        XCTAssertEqual(outcome.step.summary, [
            "seat from top: blocked by screw holes or damage", "front from drawer_front: part is damaged",
            "ghost from nope: no such part", "zero from side_left: size must be more than 0 mm",
            "a from side_right: fits, 72 mm to spare", "b from side_right: no room left after the other cuts",
        ].joined(separator: "; "))
        let rows = try XCTUnwrap(outcome.result.response["results"]?.arrayValue)
        XCTAssertEqual(rows.map { $0["blocked_by"] },
                       ["blocked_by_keep_outs", "damaged", "unknown_part", "invalid_size", nil, "no_room_left"])
        XCTAssertEqual(rows[0]["hint"]?.stringValue?.contains("362"), true)
        XCTAssertEqual(rows[2]["hint"], "Use one of: top, side_left, side_right, drawer_front.")
    }

    func testCheckFitParticleboardOnlyWhole() throws {
        let example = try Fixtures.inventory()
        let parts = example.parts.map { part in
            part.id != "top" ? part : Part(damaged: false, heightMm: 400, id: "top", keepOuts: [], material: .particleboardMDF,
                                           thicknessMm: 19, type: .top, widthMm: 460)
        }
        let board = try executor(Inventory(parts: parts, scanID: "s"))
        XCTAssertEqual(try checkFit([fitItem("seat", "top", 400, 300)], on: board).step.summary,
                       "seat from top: particleboard can't be cut")
        XCTAssertEqual(try checkFit([fitItem("cubby", "top", 460, 400)], on: board).step.status, .pass)
    }

    func testCheckFitBadArguments() throws {
        let tool = try executor()
        func error(_ args: JSON) -> String? { errorText(tool.run(ToolCall(name: "check_fit", args: args), index: 0)) }
        XCTAssertEqual(error(["reason": "r"]), "placements is missing")
        XCTAssertEqual(error(["placements": []]), "placements is empty")
        XCTAssertEqual(error(["placements": "seat"]), "placements must be a list")
        XCTAssertEqual(error(["placements": [5]]), "placements[0] must be an object")
        XCTAssertEqual(error(["placements": [fitItem("seat", "top", "452", 300)]]), "placements[0].width_mm must be a number")
        XCTAssertEqual(error(["placements": [["new_part": 7]]]), "placements[0].new_part must be text")
        XCTAssertEqual(error([1, 2]), "the arguments must be an object")
        let outcome = tool.run(ToolCall(name: "check_fit", args: ["placements": []]), index: 4)
        XCTAssertEqual(outcome.step, AgentStep(index: 4, reason: "", status: .error, summary: "error: placements is empty",
                                               tool: .checkFit))
    }

    // MARK: - check_sag

    func testCheckSagPassesAndFails() throws {
        let call = ToolCall(name: "check_sag", args: ["reason": "Will it hold?", "items": [
            sagItem("seat", "top", "seat", span: 360, depth: 300), sagItem("shelf", "top", "shelf", span: 900, depth: 280),
        ]])
        let outcome = try executor().run(call, index: 2)
        XCTAssertEqual(outcome.step, AgentStep(
            index: 2, reason: "Will it hold?", status: .fail,
            summary: "seat: bends 0.4 of 0.6 mm allowed; shelf: bends 1.9 of 1.5 mm allowed, too much", tool: .checkSag))
        let rows = try XCTUnwrap(outcome.result.response["results"]?.arrayValue)
        XCTAssertEqual(rows[0]["deflection_mm"], 0.386)
        XCTAssertEqual(rows[0]["limit_mm"], 0.6)
        XCTAssertEqual(rows.map { $0["passes"] }, [true, false])
        XCTAssertEqual(outcome.result.response["all_pass"], false)
    }

    func testCheckSagProblemRows() throws {
        let call = ToolCall(name: "check_sag", args: ["items": [
            sagItem("ghost", "nope", "seat", span: 360, depth: 300), sagItem("flat", "top", "seat", span: 0, depth: 300),
        ]])
        let outcome = try executor().run(call, index: 0)
        XCTAssertEqual(outcome.step.summary, "ghost: no such part \"nope\"; flat: span must be more than 0 mm, got 0")
        XCTAssertEqual(outcome.step.status, .fail)
    }

    func testCheckSagBadArguments() throws {
        let tool = try executor()
        func error(_ items: JSON) -> String? { errorText(tool.run(ToolCall(name: "check_sag", args: ["items": items]), index: 0)) }
        XCTAssertEqual(error([sagItem("leg", "side_left", "support", span: 300, depth: 300)]), "items[0].role must be seat or shelf")
        XCTAssertEqual(error([sagItem("seat", "top", "seat", span: "long", depth: 300)]), "items[0].span_mm must be a number")
        XCTAssertEqual(error([sagItem("seat", "top", "seat", span: 360, depth: nil)]), "items[0].depth_mm is missing")
    }

    // MARK: - submit_plan

    func testSubmitSamplePlanIsAccepted() throws {
        let outcome = try submit(JSON.from(Fixtures.benchDraft()))
        XCTAssertEqual(outcome.step, AgentStep(index: 7, reason: "Done.", status: .accepted,
                                               summary: "accepted by the validator: 3 parts, 52.1% reused", tool: .submitPlan))
        XCTAssertEqual(outcome.result.response, ["accepted": true, "reuse_percent": 52.1])
        let accepted = try XCTUnwrap(outcome.accepted)
        XCTAssertTrue(accepted.validation.passes)
        XCTAssertEqual(accepted.plan.id, "plan-agent")
        XCTAssertEqual(accepted.plan.overallMm, Vector3(x: 400, y: 399, z: 300))
    }

    func testSubmitTooWideSeatIsRejectedWithTheMessage() throws {
        var plan = try JSON.from(Fixtures.benchDraft())
        var parts = try XCTUnwrap(plan["new_parts"]?.arrayValue)
        var seat = try XCTUnwrap(parts[0].objectValue)
        seat["width_mm"] = 453
        parts[0] = .object(seat)
        plan = .object((plan.objectValue ?? [:]).merging(["new_parts": .array(parts)]) { _, new in new })

        let outcome = try submit(plan)
        let message = "seat: needs 461 × 308 mm including the 8 mm cutting margin, but top is 460 × 400 mm. "
            + "Fits with width 443 mm or less at height 300 mm."
        XCTAssertEqual(outcome.result.response, ["accepted": false, "violations": [.string(message)]])
        XCTAssertEqual(outcome.step.status, .fail)
        XCTAssertEqual(outcome.step.summary, "rejected, 1 problem: " + message)
        XCTAssertNil(outcome.accepted)
    }

    func testSubmitRespectsTheSizeLimit() throws {
        let limits = SizeLimits(maxDepthMm: 200, maxHeightMm: 300, maxWidthMm: nil)
        let outcome = try submit(JSON.from(Fixtures.benchDraft()), limits: limits)
        XCTAssertEqual(outcome.step.summary.hasPrefix("rejected, 2 problems: The build is 399 mm tall"), true)
    }

    func testSubmitMalformedPlans() throws {
        let part: JSON = ["name": "seat", "source_part_id": "top", "width_mm": 400, "height_mm": 300, "role": "seat"]
        func error(_ plan: JSON) throws -> String? { errorText(try submit(plan)) }
        XCTAssertEqual(try error(["new_parts": [part], "steps": [], "hardware": []]), "plan: template is missing")
        XCTAssertEqual(try error(["template": nil, "new_parts": [part], "steps": [], "hardware": []]), "plan: template is missing")
        XCTAssertEqual(try error(["template": "chair", "new_parts": [part], "steps": [], "hardware": []]),
                       "plan: template has a value that isn't allowed")
        let wide: JSON = ["name": "seat", "source_part_id": "top", "width_mm": "wide", "height_mm": 300, "role": "seat"]
        XCTAssertEqual(try error(["template": "bench", "new_parts": [wide], "steps": [], "hardware": []]),
                       "plan: new_parts[0].width_mm has the wrong type")
        XCTAssertEqual(try error("a bench"), "plan: the plan has the wrong type")
        XCTAssertEqual(try error(["template": "bench", "new_parts": [], "steps": [], "hardware": []]),
                       "plan.new_parts is empty: list every part of the build")
        let missing = try executor().run(ToolCall(name: "submit_plan", args: ["reason": "r"]), index: 0)
        XCTAssertEqual(errorText(missing), "arguments.plan is missing")
    }

    // MARK: - Other calls

    func testUnknownToolIsAnErrorNotACrash() throws {
        let outcome = try executor().run(ToolCall(name: "cut_wood", args: ["reason": "Let's cut."]), index: 5)
        XCTAssertEqual(outcome.result, ToolResult(name: "cut_wood", response: [
            "error": "There is no tool \"cut_wood\". Use check_fit, check_sag or submit_plan.",
        ]))
        XCTAssertEqual(outcome.step.tool, .note)
        XCTAssertEqual(outcome.step.status, .error)
        XCTAssertEqual(outcome.step.reason, "Let's cut.")
        XCTAssertEqual(outcome.step.index, 5)
    }

    func testNeutralAgentTypes() {
        let turn = ModelTurn(calls: [ToolCall(name: "check_fit", args: [:])])
        XCTAssertNil(turn.text, "a turn with calls has no text by default")
        XCTAssertEqual(ModelTurn(calls: [], text: "Done.").text, "Done.")
        XCTAssertEqual(turn.calls.first?.name, "check_fit")
        let optional = ParamProperty(name: "span_mm", schema: .number("span"), required: false)
        XCTAssertFalse(optional.required)
        XCTAssertTrue(ParamProperty(name: "reason", schema: .string("why")).required, "required by default")
        let spec = ToolSpec(name: "t", description: "d", parameters: .object([optional], "args"))
        XCTAssertEqual(spec, ToolSpec(name: "t", description: "d", parameters: .object([optional], "args")))
        XCTAssertNotEqual(ParamSchema.integer("n"), ParamSchema.boolean("n"))
    }

    func testDecodingMessageForOtherErrors() {
        XCTAssertEqual(DecodingMessage.describe(ToolInputError("x")), "ToolInputError(message: \"x\")")
        XCTAssertEqual(DecodingMessage.path([]), "the plan")
    }

    func testToolSpecs() {
        XCTAssertEqual(AgentTools.all.map(\.name), ["check_fit", "check_sag", "submit_plan"])
        for tool in AgentTools.all {
            guard case let .object(properties, _) = tool.parameters else { return XCTFail("\(tool.name) takes an object") }
            XCTAssertEqual(properties.first, AgentTools.reason, "\(tool.name) asks for a reason first")
            XCTAssertTrue(properties.allSatisfy(\.required))
        }
        XCTAssertTrue(AgentTools.checkFit.description.contains("Do not add margins yourself."))
    }
}
