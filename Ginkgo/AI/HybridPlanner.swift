import Foundation
import GinkgoCore

/// What one on-device planning attempt produced.
struct DevicePlanResult: Sendable, Equatable {
    var accepted: AcceptedPlan?
    var trace: [AgentStep]
    /// Plans the validator rejected (failed checks and rejected submits) during the attempt.
    var rejections: Int
    /// The model that answered, for the routing log.
    var model: String
    /// Why the run stopped early, when it threw (for the log; the screen shows plain words).
    var error: String?
}

/// Plans on this iPhone. `OnDevicePlanner` is the real one; tests pass a fake.
protocol DevicePlanning: Sendable {
    var isAvailable: Bool { get }
    func plan(inventory: Inventory, request: String, onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult
}

/// The result of a hybrid run: the plan (or the safe fallback), where it was made and why, and the log lines.
struct HybridOutcome: Sendable {
    var outcome: AgentOutcome
    var route: Route
    var entries: [RoutingEntry]
}

/// Plans a build the hybrid way. Numbers go to the on-device model first; if it isn't available, or the validator
/// rejects its plans `HybridRouter.deviceAttempts` times, the cloud (Gemini through Firebase AI Logic) takes over;
/// with no network, tested rules make the plan. Every plan, from anywhere, has passed the same validator.
struct HybridPlanner: Sendable {
    typealias CloudPlanning = @Sendable (Inventory, String, @escaping @Sendable (AgentStep) -> Void) async -> AgentOutcome

    var device: any DevicePlanning
    var cloud: CloudPlanning
    var cloudModelName: String
    /// Injected so tests control time.
    var now: @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    var date: @Sendable () -> Date = { Date() }

    func run(inventory: Inventory, request: String, online: Bool,
             onStep: @escaping @Sendable (AgentStep) -> Void) async -> HybridOutcome {
        var entries: [RoutingEntry] = []
        var trace: [AgentStep] = []
        var rejections = 0
        var route = HybridRouter.route(.planFromNumbers, conditions(online: online, rejections: rejections))

        if route.venue == .device {
            let start = now()
            let result = await device.plan(inventory: inventory, request: request, onStep: onStep)
            trace = result.trace
            rejections = result.rejections
            entries.append(entry(route, model: result.model, since: start,
                                 verdict: result.accepted == nil ? .failed : .passed))
            if let accepted = result.accepted {
                return HybridOutcome(outcome: .accepted(plan: accepted.plan, validation: accepted.validation, trace: trace),
                                     route: route, entries: entries)
            }
            route = HybridRouter.route(.planFromNumbers, RouteConditions(
                deviceModelAvailable: device.isAvailable, online: online, deviceRejections: rejections,
                deviceFinishedWithoutPlan: true))
        }

        let start = now()
        let outcome: AgentOutcome
        let model: String
        if route.venue == .cloud {
            let cloudOutcome = await cloud(inventory, request, onStep)
            outcome = Self.prefixed(cloudOutcome, with: trace)
            model = Self.answered(by: cloudOutcome, cloudModel: cloudModelName)
        } else {
            outcome = Self.ruleBased(inventory: inventory, trace: trace, reason: route.reason.message)
            model = "rule-based"
        }
        let verdict: ValidatorVerdict = outcome.plan == nil ? .failed : .passed
        entries.append(entry(route, model: model, since: start, verdict: verdict))
        return HybridOutcome(outcome: outcome, route: route, entries: entries)
    }

    private func conditions(online: Bool, rejections: Int) -> RouteConditions {
        RouteConditions(deviceModelAvailable: device.isAvailable, online: online, deviceRejections: rejections)
    }

    private func entry(_ route: Route, model: String, since start: ContinuousClock.Instant,
                       verdict: ValidatorVerdict) -> RoutingEntry {
        let elapsed = now() - start
        let ms = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
        return RoutingEntry(task: .planFromNumbers, venue: route.venue, reason: route.reason, model: model,
                            durationMs: ms, verdict: verdict, date: date())
    }

    /// The device's steps stay on screen ahead of the cloud's, so the whole story is visible.
    static func prefixed(_ outcome: AgentOutcome, with earlier: [AgentStep]) -> AgentOutcome {
        guard !earlier.isEmpty else { return outcome }
        let shifted = outcome.trace.enumerated().map { offset, step in
            AgentStep(index: earlier.count + offset, reason: step.reason, status: step.status,
                      summary: step.summary, tool: step.tool)
        }
        switch outcome {
        case let .accepted(plan, validation, _):
            return .accepted(plan: plan, validation: validation, trace: earlier + shifted)
        case let .fallback(plan, validation, _, reason):
            return .fallback(plan: plan, validation: validation, trace: earlier + shifted, reason: reason)
        }
    }

    /// The cloud run accepted Gemini's plan, or fell back to the rules inside PlanAgent.
    static func answered(by outcome: AgentOutcome, cloudModel: String) -> String {
        if case .accepted = outcome { return cloudModel }
        return "rule-based"
    }

    /// No network and no usable on-device plan: Ginkgo's tested rules make the plan.
    static func ruleBased(inventory: Inventory, trace: [AgentStep], reason: String) -> AgentOutcome {
        let safe = RuleBasedPlanner.bench(inventory: inventory)
        let step = AgentStep(index: trace.count, reason: reason, status: safe == nil ? .error : .info,
                             summary: safe == nil ? "No safe plan can be made from these parts."
                                                  : "Showing the rule-based bench instead; it passes the validator.",
                             tool: .fallback)
        return .fallback(plan: safe?.plan, validation: safe?.validation, trace: trace + [step], reason: reason)
    }
}
