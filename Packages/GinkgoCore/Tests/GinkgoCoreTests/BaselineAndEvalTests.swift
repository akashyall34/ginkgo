import Foundation
@testable import GinkgoCore
import XCTest

final class ChatbotBaselineTests: XCTestCase {
    private func part(_ name: String, _ from: String, _ size: [Double], _ role: String) -> ChatbotPart {
        ChatbotPart(name: name, from: from, widthMm: size[0], heightMm: size[1], role: role)
    }

    private func judge(_ answer: ChatbotAnswer) throws -> (plan: Plan, result: ValidationResult) {
        let inventory = try Fixtures.inventory()
        let plan = ChatbotBaseline.plan(from: answer, inventory: inventory)
        return (plan, Validator.validate(plan: plan, inventory: inventory, limits: nil))
    }

    func testTypicalChatbotAnswerFailsTheValidator() throws {
        // What a chatbot says from a photo: use the whole top, full-width legs, no margins.
        let answer = ChatbotAnswer(template: "bench", parts: [
            part("seat", "top", [460, 400], "seat"), part("leg_1", "side", [380, 450], "support"),
            part("leg_2", "side", [380, 450], "support"),
        ], steps: ["Use the top as the seat.", "Cut the sides to 450 mm."])
        let (plan, result) = try judge(answer)
        XCTAssertEqual(plan.source, .chatbot)
        XCTAssertEqual(plan.newParts.map(\.sourcePartID), ["top", "side_left", "side_right"], "two sides map left, then right")
        XCTAssertEqual(plan.steps, answer.steps)
        XCTAssertFalse(result.passes)
        XCTAssertEqual(result.violations.map(\.code), [.doesNotFit, .doesNotFit],
                       "the whole top reused as a seat is fine; the legs forgot the margin")
    }

    func testKindsThePieceDoesntHaveAreUnknownAndUsedUpKindsAreReused() throws {
        let answer = ChatbotAnswer(template: "castle", parts: [
            part("rail", "rail", [300, 70], "brace"), part("a", "top", [100, 100], "other"), part("b", "top", [100, 100], "other"),
        ], steps: [])
        let (plan, result) = try judge(answer)
        XCTAssertEqual(plan.newParts.map(\.sourcePartID), ["rail", "top", "top"])
        XCTAssertEqual(plan.template, .bench, "an unknown template is judged as a bench")
        XCTAssertEqual(plan.newParts.first?.role, .other, "an unknown role is judged as other")
        XCTAssertEqual(result.violations.map(\.code), [.unknownPart])
    }

    func testPromptVariantsAndRequest() throws {
        XCTAssertFalse(ChatbotBaseline.prompt(measured: nil).contains("measures"), "variant 1: photo only")
        XCTAssertTrue(ChatbotBaseline.prompt(measured: Vector3(x: 315, y: 600, z: 365))
            .hasSuffix("It measures 315 mm wide, 600 mm tall and 365 mm deep."), "variant 2: photo plus the right dimensions")
        let body = ChatbotBaseline.request(photo: Data([1, 2, 3]), mimeType: "image/jpeg", measured: nil)
        XCTAssertEqual(body["generationConfig"]?["responseSchema"]?["required"], ["template", "parts", "steps"])
        XCTAssertNil(body["tools"], "a plain chatbot: no tools, no checks")
    }

    func testParse() throws {
        let text = #"{"template": "bench", "steps": ["Cut."], "parts": [{"name": "seat", "from": "top", "width_mm": 400, "#
            + #""height_mm": 300, "role": "seat"}]}"#
        XCTAssertEqual(try ChatbotBaseline.parse(text).parts.first, part("seat", "top", [400, 300], "seat"))
        XCTAssertThrowsError(try ChatbotBaseline.parse("Sure! Here's a cut list:"))
    }
}

final class EvalTests: XCTestCase {
    private func step(_ tool: Tool, _ status: Status) -> AgentStep {
        AgentStep(index: 0, reason: "", status: status, summary: "", tool: tool)
    }

    /// [accepted first try, accepted after a repair, safe fallback, honest no]
    private func outcomes() throws -> [AgentOutcome] {
        let plan = try Fixtures.planBench()
        let validation = Validator.validate(plan: plan, inventory: try Fixtures.inventory(), limits: nil)
        return [.accepted(plan: plan, validation: validation, trace: [step(.checkFit, .pass), step(.submitPlan, .accepted)]),
                .accepted(plan: plan, validation: validation, trace: [step(.submitPlan, .fail), step(.submitPlan, .accepted)]),
                .fallback(plan: plan, validation: validation, trace: [step(.fallback, .info)], reason: "slow"),
                .fallback(plan: nil, validation: nil, trace: [step(.fallback, .error)], reason: "no plan")]
    }

    func testRowsCountFirstTryRepairsAndFallbacks() throws {
        let made = try outcomes()
        let rows = EvalSummary.rows([
            EvalRun(variant: "stool", outcome: made[0], seconds: 10, calls: 2),
            EvalRun(variant: "box", outcome: made[3], seconds: 1, calls: 1),
            EvalRun(variant: "stool", outcome: made[1], seconds: 20, calls: 4),
            EvalRun(variant: "stool", outcome: made[2], seconds: 30, calls: 6),
        ])
        XCTAssertEqual(rows, [
            EvalRow(variant: "stool", runs: 3, acceptedFirstTry: 1, acceptedAfterRepair: 1, fallbacks: 1, safeFallbacks: 1,
                    averageSeconds: 20, averageCalls: 4),
            EvalRow(variant: "box", runs: 1, acceptedFirstTry: 0, acceptedAfterRepair: 0, fallbacks: 1, safeFallbacks: 0,
                    averageSeconds: 1, averageCalls: 1),
        ])
        let table = EvalSummary.markdown(rows)
        XCTAssertTrue(table.contains("| stool | 3 | 1 | 1 | 1 (1) | 20.0 s | 4.0 |"))
        XCTAssertTrue(table.hasSuffix("Validated plans shown: 3 of 4 runs; any others were an honest \"no safe plan\". "
            + "No invalid plan was ever shown."))
        XCTAssertFalse(EvalSummary.acceptedFirstTry(made[2]))
    }

    func testStandardVariants() throws {
        let variants = EvalVariant.standard(try Fixtures.inventory(), name: "nightstand")
        XCTAssertEqual(variants.map(\.name), ["nightstand", "nightstand, particleboard top", "nightstand, damaged side",
                                              "nightstand, max width 420 mm"])
        XCTAssertEqual(variants[1].inventory.parts.first?.material, .particleboardMDF)
        XCTAssertEqual(variants[2].inventory.parts.first { $0.id == "side_left" }?.damaged, true)
        XCTAssertEqual(variants[3].limits?.maxWidthMm, 420)
        XCTAssertNil(variants[0].limits)
    }

    func testChatbotFailureRate() throws {
        let inventory = try Fixtures.inventory()
        let good = Validator.validate(plan: try Fixtures.planBench(), inventory: inventory, limits: nil)
        let bad = Validator.validate(plan: try Fixtures.planChatbot(), inventory: inventory, limits: nil)
        let noPlan = Validator.validate(
            plan: ChatbotBaseline.plan(from: ChatbotAnswer(template: "no_cut", parts: [], steps: ["It can't be done."]),
                                       inventory: inventory),
            inventory: inventory, limits: nil)
        let outcomes = EvalSummary.chatbotOutcomes([bad, good, bad, noPlan])
        XCTAssertEqual(outcomes, ChatbotOutcomes(unsafe: 2, noPlan: 1, valid: 1), "giving up isn't counted as an unsafe plan")
        XCTAssertEqual(outcomes.summary,
                       "unsafe plans (an impossible cut, unsafe part or sag): 2 · no plan at all: 1 · valid plans: 1")
    }
}
