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
    let inventory: Inventory

    init(inventory: Inventory) { self.inventory = inventory }

    var isRunning: Bool { outcome == nil }

    /// What happened, in one line for the top of the screen.
    var headline: String {
        switch outcome {
        case nil: return "Gemini is planning, and Ginkgo checks every step…"
        case .accepted: return "Gemini's plan passed every check"
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

    var proof: ProofModel? {
        guard let plan = outcome?.plan, let validation = outcome?.validation else { return nil }
        return ProofModel(plan: plan, result: validation, inventory: inventory)
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
