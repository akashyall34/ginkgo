import Foundation
import GinkgoCore
import Observation

/// AI suggests, code decides: runs Vivek's PlanAgent on the confirmed parts and keeps its live trace.
/// Whatever happens, only a plan the validator accepted, or the rule-based fallback, reaches Proof.
@MainActor
@Observable
final class PlanningModel {
    private(set) var steps: [AgentStep] = []
    private(set) var outcome: AgentOutcome?
    /// Where the plan is being made, and why (shown as a badge). Nil for a cloud-only run.
    private(set) var route: Route?
    /// What the hybrid run recorded, for the routing log.
    private(set) var routing: [RoutingEntry] = []
    /// "Improve this plan": what comparing the two plans found, once it's been run.
    private(set) var improvement: PlanImprovement.Comparison?
    private(set) var isImproving = false
    /// Whether the phone has a network right now; the screen keeps it current so the offer appears when it returns.
    var online = false
    let inventory: Inventory

    init(inventory: Inventory) { self.inventory = inventory }

    var isRunning: Bool { outcome == nil }

    /// What happened, in one line for the top of the screen.
    var headline: String {
        switch outcome {
        case nil:
            return route?.venue == .device ? "Planning on this iPhone, and Ginkgo checks every step…"
                                           : "Gemini is planning, and Ginkgo checks every step…"
        case .accepted:
            return route?.venue == .device ? "Planned on this iPhone, and it passed every check"
                                           : "Gemini's plan passed every check"
        case .fallback(let plan, _, _, _):
            return plan == nil ? "No safe plan can be made from these parts"
                               : "Gemini's plan didn't pass, so Ginkgo made its own safe plan"
        }
    }

    /// Why the fallback was used, when it was.
    var fallbackReason: String? {
        if case .fallback(_, _, _, let reason) = outcome {
            // Network errors come back as raw text; say it plainly instead.
            return reason.contains("Error") || reason.contains("error") ? "Gemini couldn't be reached." : reason
        }
        return nil
    }

    /// Offered once, for a finished plan Gemini in the cloud didn't make, while online.
    var canImprove: Bool {
        improvement == nil && !isImproving && PlanImprovement.isOffered(route: route, outcome: outcome, online: online)
    }

    /// Gemini replans the same confirmed parts in the cloud; the better plan that passes is the one shown.
    func improve(planner: HybridPlanner, request: String = Prompts.defaultRequest) async {
        guard canImprove, let original = outcome else { return }
        isImproving = true
        let offset = original.trace.count
        let result = await planner.improve(original: original, inventory: inventory, request: request) { step in
            let shifted = AgentStep(index: offset + step.index, reason: step.reason, status: step.status,
                                    summary: step.summary, tool: step.tool)
            Task { @MainActor in self.steps.append(shifted) }
        }
        steps = result.outcome.trace
        outcome = result.outcome
        if result.comparison.choice == .improved { route = result.route }
        routing.append(result.entry)
        improvement = result.comparison
        isImproving = false
    }

    var proof: ProofModel? {
        guard let plan = outcome?.plan, let validation = outcome?.validation else { return nil }
        return ProofModel(plan: plan, result: validation, inventory: inventory)
    }

    /// The hybrid way: on this iPhone first, the cloud when it helps, tested rules with no network.
    func run(planner: HybridPlanner, online: Bool, request: String = Prompts.defaultRequest) async {
        steps = []
        outcome = nil
        routing = []
        improvement = nil
        self.online = online
        let conditions = RouteConditions(deviceModelAvailable: planner.device.isAvailable, online: online)
        route = HybridRouter.route(.planFromNumbers, conditions)
        let result = await planner.run(inventory: inventory, request: request, online: online) { step in
            Task { @MainActor in self.steps.append(step) }
        }
        steps = result.outcome.trace
        route = result.route
        routing = result.entries
        outcome = result.outcome
    }

    func run(model: any AgentModel, request: String = Prompts.defaultRequest,
             agent: (any AgentModel) -> PlanAgent = { PlanAgent(model: $0, maxTurns: 6) }) async {
        steps = []
        outcome = nil
        let result = await agent(model).run(inventory: inventory, limits: nil, request: request) { step in
            Task { @MainActor in self.steps.append(step) }
        }
        steps = result.trace
        outcome = result
    }
}
