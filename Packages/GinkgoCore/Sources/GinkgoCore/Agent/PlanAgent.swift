import Foundation

/// How a planning run ended. A fallback still carries a safe plan when one exists.
public enum AgentOutcome: Sendable, Equatable {
    case accepted(plan: Plan, validation: ValidationResult, trace: [AgentStep])
    case fallback(plan: Plan?, validation: ValidationResult?, trace: [AgentStep], reason: String)

    public var plan: Plan? {
        switch self {
        case let .accepted(plan, _, _): return plan
        case let .fallback(plan, _, _, _): return plan
        }
    }

    public var validation: ValidationResult? {
        switch self {
        case let .accepted(_, validation, _): return validation
        case let .fallback(_, validation, _, _): return validation
        }
    }

    public var trace: [AgentStep] {
        switch self {
        case let .accepted(_, _, trace): return trace
        case let .fallback(_, _, trace, _): return trace
        }
    }
}

/// AI suggests, code decides: the model proposes and repairs a plan through our tools; only a plan the
/// validator accepts comes back as accepted. Anything else ends in the rule-based fallback.
public struct PlanAgent: Sendable {
    public var model: any AgentModel
    /// Model replies allowed. 2 = the spec's "propose + one repair".
    public var maxTurns: Int
    public var timeout: Duration
    /// Injected so tests control time.
    public var sleep: @Sendable (Duration) async throws -> Void

    public init(model: any AgentModel, maxTurns: Int = 6, timeout: Duration = .seconds(25),
                sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.model = model
        self.maxTurns = maxTurns
        self.timeout = timeout
        self.sleep = sleep
    }

    public func run(inventory: Inventory, limits: SizeLimits?, request: String,
                    onStep: @escaping @Sendable (AgentStep) -> Void) async -> AgentOutcome {
        let recorder = TraceRecorder(onStep: onStep)
        let executor = ToolExecutor(inventory: inventory, limits: limits)
        let user = Prompts.plannerUser(inventory: inventory, limits: limits, request: request)
        let end = await race(executor: executor, user: user, recorder: recorder)
        if case let .accepted(accepted) = end {
            return .accepted(plan: accepted.plan, validation: accepted.validation, trace: await recorder.steps)
        }
        let reason = end.reason(maxTurns: maxTurns, timeout: timeout)
        let safe = RuleBasedPlanner.bench(inventory: inventory, limits: limits)
        let outcome = safe == nil
            ? "No safe plan can be made from these parts."
            : "Showing the rule-based bench instead; it passes the validator."
        await recorder.record(AgentStep(
            index: await recorder.count, reason: reason, status: safe == nil ? .error : .info,
            summary: (end.detail.map { "\($0). " } ?? "") + outcome, tool: .fallback))
        return .fallback(plan: safe?.plan, validation: safe?.validation, trace: await recorder.steps, reason: reason)
    }

    /// Runs the conversation against the timeout; whichever finishes first wins and the other is cancelled.
    func race(executor: ToolExecutor, user: String, recorder: TraceRecorder) async -> LoopEnd {
        await withTaskGroup(of: LoopEnd.self) { group in
            group.addTask {
                do {
                    return try await converse(executor: executor, user: user, recorder: recorder)
                } catch {
                    return .failed("\(error)")
                }
            }
            group.addTask {
                do {
                    try await self.sleep(self.timeout)
                    return .timedOut
                } catch {
                    return .failed("cancelled")
                }
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }

    func converse(executor: ToolExecutor, user: String, recorder: TraceRecorder) async throws -> LoopEnd {
        let session = try await model.startSession(system: Prompts.plannerSystem, tools: AgentTools.all)
        var turn = try await session.send(text: user)
        var replies = 1
        var nudged = false
        while true {
            if turn.calls.isEmpty {
                if nudged { return .noPlan }
                nudged = true
                await recorder.record(AgentStep(
                    index: await recorder.count, reason: turn.text ?? "", status: .info,
                    summary: "Gemini answered without using the tools; reminded it to check and submit.", tool: .note))
                guard replies < maxTurns else { return .outOfTurns }
                turn = try await session.send(text: Prompts.nudge)
            } else {
                var results: [ToolResult] = []
                for call in turn.calls {
                    let outcome = executor.run(call, index: await recorder.count)
                    await recorder.record(outcome.step)
                    if outcome.step.status == .accepted, let accepted = outcome.accepted { return .accepted(accepted) } // MUTANT:accept
                    results.append(outcome.result)
                }
                guard replies < maxTurns else { return .outOfTurns }
                turn = try await session.send(results: results)
            }
            replies += 1
        }
    }
}

/// Why the conversation stopped.
enum LoopEnd: Sendable {
    case accepted(AcceptedPlan)
    case outOfTurns
    case noPlan
    case failed(String)
    case timedOut

    func reason(maxTurns: Int, timeout: Duration) -> String {
        switch self {
        case .accepted: return "Accepted"
        case .outOfTurns: return "Gemini didn't reach an accepted plan in \(maxTurns) steps"
        case .noPlan: return "Gemini stopped without submitting a plan"
        case .failed: return "Couldn't reach Gemini"
        case .timedOut: return "Gemini took longer than \(PlanAgent.seconds(timeout)) s"
        }
    }

    /// The technical detail behind a failure, for the trace (for example an HTTP status and body).
    var detail: String? {
        if case let .failed(detail) = self { return detail }
        return nil
    }
}

extension PlanAgent {
    /// "25" or "0.1".
    static func seconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        return Format.mm(Double(seconds) + Double(attoseconds) / 1e18)
    }
}

/// Collects the trace in order and passes each step on as it happens.
actor TraceRecorder {
    private(set) var steps: [AgentStep] = []
    private let onStep: @Sendable (AgentStep) -> Void

    init(onStep: @escaping @Sendable (AgentStep) -> Void) {
        self.onStep = onStep
    }

    var count: Int { steps.count }

    func record(_ step: AgentStep) {
        steps.append(step)
        onStep(step)
    }
}
