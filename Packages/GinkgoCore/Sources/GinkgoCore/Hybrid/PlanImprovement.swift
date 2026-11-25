import Foundation

/// "Improve this plan": once the network is back, Gemini replans in the cloud and the validator checks both plans.
/// The cloud plan replaces the first one only when it passes and reuses more of the wood, so improving never makes
/// a plan worse.
public enum PlanImprovement {
    public enum Choice: Sendable, Equatable {
        case original
        case improved
    }

    public struct Comparison: Sendable, Equatable {
        public var choice: Choice
        /// One line for the screen saying what was compared and why this plan was kept.
        public var message: String
    }

    /// Offered when there is a finished plan that Gemini in the cloud didn't make, and the phone is online.
    public static func isOffered(route: Route?, outcome: AgentOutcome?, online: Bool) -> Bool {
        guard online, let outcome else { return false }
        if case .accepted = outcome, route?.venue == .cloud { return false }
        return true
    }

    /// Compares the plans by the share of wood reused, at the whole percent the screen shows.
    public static func compare(original: AgentOutcome, improved: AgentOutcome) -> Comparison {
        guard case let .accepted(_, validation, _) = improved, validation.passes else {
            return Comparison(choice: .original,
                              message: "Gemini's plan didn't pass the validator, so this plan stays.")
        }
        let after = percent(validation.reusePercent)
        guard let first = original.validation, original.plan != nil, first.passes else {
            return Comparison(choice: .improved,
                              message: "Improved by Gemini in the cloud: it found a plan that passes, \(after)% of the wood reused.")
        }
        let before = percent(first.reusePercent)
        if after > before {
            return Comparison(choice: .improved,
                              message: "Improved by Gemini in the cloud: \(after)% of the wood reused, up from \(before)%.")
        }
        return Comparison(choice: .original,
                          message: "Gemini's plan passes but reuses \(after)% of the wood, not more than \(before)%, so this plan stays.")
    }

    static func percent(_ value: Double) -> Int { Int(value.rounded()) }
}
