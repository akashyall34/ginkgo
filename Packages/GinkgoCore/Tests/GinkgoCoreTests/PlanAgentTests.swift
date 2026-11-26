import Foundation
@testable import GinkgoCore
import XCTest

// MARK: - A scripted fake model: returns pre-written turns and records what it was sent.

enum Reply: Sendable {
    case turn(ModelTurn)
    case fail
    case hang
}

enum Sent: Sendable, Equatable {
    case text(String)
    case results([ToolResult])
}

struct FakeModelError: Error, CustomStringConvertible {
    var description: String { "HTTP 503: model overloaded" }
}

actor ScriptedSession: AgentSession {
    private var replies: [Reply]
    private(set) var sent: [Sent] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    func send(text: String) async throws -> ModelTurn {
        sent.append(.text(text))
        return try await next()
    }

    func send(results: [ToolResult]) async throws -> ModelTurn {
        sent.append(.results(results))
        return try await next()
    }

    /// Replies in order; the last one repeats forever.
    private func next() async throws -> ModelTurn {
        let reply = replies.count > 1 ? replies.removeFirst() : replies.first ?? .fail
        switch reply {
        case let .turn(turn): return turn
        case .fail: throw FakeModelError()
        case .hang:
            try await Task.sleep(for: .seconds(3600))
            throw FakeModelError()
        }
    }
}

actor ScriptedModel: AgentModel {
    let session: ScriptedSession
    let failToStart: Bool
    private(set) var system: String?
    private(set) var tools: [ToolSpec] = []

    init(_ replies: [Reply], failToStart: Bool = false) {
        self.session = ScriptedSession(replies)
        self.failToStart = failToStart
    }

    func startSession(system: String, tools: [ToolSpec]) async throws -> any AgentSession {
        self.system = system
        self.tools = tools
        if failToStart { throw FakeModelError() }
        return session
    }
}

final class StepLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [AgentStep] = []

    func add(_ step: AgentStep) {
        lock.lock()
        items.append(step)
        lock.unlock()
    }

    var all: [AgentStep] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

// MARK: - Tests

final class PlanAgentTests: XCTestCase {
    private func call(_ name: String, _ args: JSON) -> ToolCall {
        ToolCall(name: name, args: args)
    }

    private func goodFit() -> ToolCall {
        call("check_fit", ["reason": "Check every cut.", "placements": [
            ["new_part": "seat", "source_part_id": "top", "width_mm": 400, "height_mm": 300],
        ]])
    }

    private func goodSag() -> ToolCall {
        call("check_sag", ["reason": "Check the seat.", "items": [
            ["new_part": "seat", "source_part_id": "top", "role": "seat", "span_mm": 360, "depth_mm": 300],
        ]])
    }

    private func submit(seatWidth: Double = 400) throws -> ToolCall {
        var plan = try XCTUnwrap(try JSON.from(Fixtures.benchDraft()).objectValue)
        var parts = try XCTUnwrap(plan["new_parts"]?.arrayValue)
        var seat = try XCTUnwrap(parts[0].objectValue)
        seat["width_mm"] = .number(seatWidth)
        parts[0] = .object(seat)
        plan["new_parts"] = .array(parts)
        return call("submit_plan", ["reason": "Submit the bench.", "plan": .object(plan)])
    }

    private func turn(_ calls: ToolCall...) -> Reply {
        .turn(ModelTurn(calls: calls))
    }

    private func run(_ model: ScriptedModel, maxTurns: Int = 6, timeout: Duration = .seconds(25),
                     limits: SizeLimits? = nil, log: StepLog = StepLog()) async throws -> AgentOutcome {
        let agent = PlanAgent(model: model, maxTurns: maxTurns, timeout: timeout)
        return await agent.run(inventory: try Fixtures.inventory(), limits: limits, request: "Make a bench.",
                               onStep: { log.add($0) })
    }

    // MARK: - Accepted

    func testAcceptedOnTheFirstSubmit() async throws {
        let model = ScriptedModel([turn(goodFit(), goodSag()), turn(try submit())])
        let outcome = try await run(model)
        guard case let .accepted(plan, validation, trace) = outcome else { return XCTFail("expected accepted, got \(outcome)") }
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.overallMm, Vector3(x: 400, y: 399, z: 300))
        XCTAssertEqual(trace.map(\.tool), [.checkFit, .checkSag, .submitPlan])
        XCTAssertEqual(trace.map(\.status), [.pass, .pass, .accepted])
        XCTAssertEqual(trace.map(\.index), [0, 1, 2])
        XCTAssertEqual(trace.map(\.reason), ["Check every cut.", "Check the seat.", "Submit the bench."])
        let system = await model.system
        let tools = await model.tools
        XCTAssertEqual(system, Prompts.plannerSystem)
        XCTAssertEqual(tools, AgentTools.all)
    }

    func testRepairAfterARejectedPlan() async throws {
        let model = ScriptedModel([turn(try submit(seatWidth: 453)), turn(try submit())])
        let outcome = try await run(model)
        XCTAssertEqual(outcome.trace.map(\.status), [.fail, .accepted])
        let sent = await model.session.sent
        guard case let .results(results) = sent[1] else { return XCTFail("the rejection goes back to the model") }
        XCTAssertEqual(results.first?.response["accepted"], false)
        XCTAssertEqual(results.first?.response["violations"]?.arrayValue?.first?.stringValue?.hasPrefix("seat: needs 461 × 308 mm"),
                       true)
        guard case .accepted = outcome else { return XCTFail("repaired plan is accepted") }
    }

    func testParallelCallsRunInOrderAndAnswerTogether() async throws {
        let model = ScriptedModel([turn(goodFit(), goodSag()), turn(try submit())])
        _ = try await run(model)
        let sent = await model.session.sent
        XCTAssertEqual(sent.count, 2)
        guard case let .text(user) = sent[0], case let .results(results) = sent[1] else { return XCTFail("text, then results") }
        XCTAssertTrue(user.contains("Request: Make a bench."))
        XCTAssertEqual(results.map(\.name), ["check_fit", "check_sag"], "one message, in call order")
    }

    func testAcceptanceStopsTheTurnImmediately() async throws {
        let model = ScriptedModel([turn(try submit(), goodFit())])
        let outcome = try await run(model)
        XCTAssertEqual(outcome.trace.map(\.tool), [.submitPlan], "the check_fit after acceptance never runs")
        let sentCount = await model.session.sent.count
        XCTAssertEqual(sentCount, 1)
    }

    func testTextOnceGetsANudgeThenAccepted() async throws {
        let model = ScriptedModel([.turn(ModelTurn(calls: [], text: "I'd make a bench.")), turn(try submit())])
        let outcome = try await run(model)
        guard case .accepted = outcome else { return XCTFail("expected accepted") }
        XCTAssertEqual(outcome.trace.first?.tool, .note)
        XCTAssertEqual(outcome.trace.first?.reason, "I'd make a bench.")
        let sent = await model.session.sent
        XCTAssertEqual(sent.last, .text(Prompts.nudge))
    }

    func testAnEmptyFirstReplyIsNudgedWithABlankReason() async throws {
        let outcome = try await run(ScriptedModel([.turn(ModelTurn(calls: [])), turn(try submit())]))
        XCTAssertEqual(outcome.trace.first?.reason, "")
    }

    // MARK: - Fallback

    func testTextTwiceFallsBack() async throws {
        let model = ScriptedModel([.turn(ModelTurn(calls: [], text: "Hmm.")), .turn(ModelTurn(calls: []))])
        let outcome = try await run(model)
        guard case let .fallback(plan, validation, trace, reason) = outcome else { return XCTFail("expected fallback") }
        XCTAssertEqual(reason, "Gemini stopped without submitting a plan")
        XCTAssertEqual(validation?.passes, true, "the fallback plan passes the validator")
        XCTAssertEqual(plan?.id, RuleBasedPlanner.planID)
        XCTAssertEqual(trace.map(\.tool), [.note, .fallback])
        XCTAssertEqual(trace.last?.status, .info)
        XCTAssertEqual(trace.last?.reason, reason)
    }

    func testNeverSubmittingRunsOutOfTurns() async throws {
        let model = ScriptedModel([turn(goodFit())])
        let outcome = try await run(model)
        guard case let .fallback(_, validation, trace, reason) = outcome else { return XCTFail("expected fallback") }
        XCTAssertEqual(reason, "Gemini didn't reach an accepted plan in 6 steps")
        XCTAssertEqual(trace.filter { $0.tool == .checkFit }.count, 6)
        XCTAssertEqual(validation?.passes, true)
        let sentCount = await model.session.sent.count
        XCTAssertEqual(sentCount, 6, "6 model replies: the first message plus 5 rounds of results")
    }

    func testTwoTurnsMeansProposeAndOneRepair() async throws {
        let model = ScriptedModel([turn(try submit(seatWidth: 453))])
        let outcome = try await run(model, maxTurns: 2)
        XCTAssertEqual(outcome.trace.map(\.tool), [.submitPlan, .submitPlan, .fallback])
        let sentCount = await model.session.sent.count
        XCTAssertEqual(sentCount, 2)
        guard case let .fallback(_, _, _, reason) = outcome else { return XCTFail("expected fallback") }
        XCTAssertEqual(reason, "Gemini didn't reach an accepted plan in 2 steps")
    }

    func testTextWithNoTurnsLeftFallsBack() async throws {
        let model = ScriptedModel([.turn(ModelTurn(calls: [], text: "Hi."))])
        let outcome = try await run(model, maxTurns: 1)
        guard case let .fallback(_, _, _, reason) = outcome else { return XCTFail("expected fallback") }
        XCTAssertEqual(reason, "Gemini didn't reach an accepted plan in 1 steps")
    }

    func testModelErrorFallsBack() async throws {
        let outcome = try await run(ScriptedModel([.fail]))
        guard case let .fallback(plan, _, trace, reason) = outcome else { return XCTFail("expected fallback") }
        XCTAssertEqual(reason, "Couldn't reach Gemini")
        XCTAssertNotNil(plan)
        XCTAssertEqual(trace.last?.summary,
                       "HTTP 503: model overloaded. Showing the rule-based bench instead; it passes the validator.")
        let failedStart = try await run(ScriptedModel([], failToStart: true))
        guard case let .fallback(_, _, _, startReason) = failedStart else { return XCTFail("expected fallback") }
        XCTAssertEqual(startReason, "Couldn't reach Gemini")
    }

    func testTimeoutFallsBack() async throws {
        let started = Date()
        let outcome = try await run(ScriptedModel([.hang]), timeout: .milliseconds(100))
        guard case let .fallback(plan, _, trace, reason) = outcome else { return XCTFail("expected fallback") }
        XCTAssertEqual(reason, "Gemini took longer than 0.1 s")
        XCTAssertNotNil(plan)
        XCTAssertEqual(trace.map(\.tool), [.fallback])
        XCTAssertLessThan(Date().timeIntervalSince(started), 5, "the hung call is cancelled, not waited for")
    }

    func testNoSafePlanMeansAnHonestNo() async throws {
        let narrow = SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: 300)
        let outcome = try await run(ScriptedModel([.fail]), limits: narrow)
        guard case let .fallback(plan, validation, trace, _) = outcome else { return XCTFail("expected fallback") }
        XCTAssertNil(plan)
        XCTAssertNil(validation)
        XCTAssertEqual(trace.last?.status, .error)
        XCTAssertEqual(trace.last?.summary.hasSuffix("No safe plan can be made from these parts."), true)
    }

    func testOnStepReceivesEveryStepInOrder() async throws {
        let log = StepLog()
        let outcome = try await run(ScriptedModel([turn(goodFit(), goodSag()), turn(try submit(seatWidth: 453)), .fail]), log: log)
        XCTAssertEqual(log.all, outcome.trace)
        XCTAssertEqual(log.all.map(\.index), [0, 1, 2, 3])
        XCTAssertEqual(log.all.last?.tool, .fallback)
    }

    // MARK: - Small pieces

    func testOutcomeAccessorsAndReasons() throws {
        let plan = try Fixtures.planBench()
        let validation = Validator.validate(plan: plan, inventory: try Fixtures.inventory(), limits: nil)
        let accepted = AgentOutcome.accepted(plan: plan, validation: validation, trace: [])
        XCTAssertEqual(accepted.plan, plan)
        XCTAssertEqual(accepted.validation, validation)
        XCTAssertEqual(accepted.trace, [])
        let end = LoopEnd.accepted(AcceptedPlan(plan: plan, validation: validation))
        XCTAssertEqual(end.reason(maxTurns: 6, timeout: .seconds(25)), "Accepted")
        XCTAssertNil(end.detail)
        XCTAssertEqual(LoopEnd.timedOut.reason(maxTurns: 6, timeout: .seconds(25)), "Gemini took longer than 25 s")
    }

    func testPlannerUserPrompt() throws {
        let inventory = try Fixtures.inventory()
        let text = Prompts.plannerUser(inventory: inventory, limits: SizeLimits(maxDepthMm: 300, maxHeightMm: nil, maxWidthMm: 420),
                                       request: "  ")
        XCTAssertTrue(text.hasPrefix("Request: Make a bench.\nSize limits: max width 420 mm, max depth 300 mm.\n"))
        XCTAssertTrue(text.contains("\"id\":\"side_left\""))
        XCTAssertEqual(text, Prompts.plannerUser(inventory: inventory,
                                                 limits: SizeLimits(maxDepthMm: 300, maxHeightMm: nil, maxWidthMm: 420), request: ""))
        XCTAssertTrue(Prompts.plannerUser(inventory: inventory, limits: nil, request: "A shelf.").contains("Size limits: none."))
        XCTAssertEqual(Prompts.describe(SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: nil)), "none.")
    }
}
