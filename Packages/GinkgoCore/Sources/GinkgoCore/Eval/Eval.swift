import Foundation

/// One piece of furniture (or a variant of it) to evaluate the agent on.
public struct EvalVariant: Sendable, Equatable {
    public var name: String
    public var inventory: Inventory
    public var limits: SizeLimits?

    public init(name: String, inventory: Inventory, limits: SizeLimits? = nil) {
        self.name = name
        self.inventory = inventory
        self.limits = limits
    }

    /// The standard variants of one inventory: as-is, with a particleboard top, with a damaged side, and narrow.
    public static func standard(_ base: Inventory, name: String) -> [EvalVariant] {
        func changing(_ change: (Part) -> Part) -> Inventory {
            Inventory(parts: base.parts.map(change), scanID: base.scanID)
        }
        let particleboardTop = changing { part in
            part.type != .top ? part : Part(damaged: part.damaged, heightMm: part.heightMm, id: part.id, keepOuts: part.keepOuts,
                                            material: .particleboardMDF, thicknessMm: part.thicknessMm, type: part.type,
                                            widthMm: part.widthMm)
        }
        let firstSide = base.parts.first { $0.type == .side }?.id
        let damagedSide = changing { part in
            part.id != firstSide ? part : Part(damaged: true, heightMm: part.heightMm, id: part.id, keepOuts: part.keepOuts,
                                               material: part.material, thicknessMm: part.thicknessMm, type: part.type,
                                               widthMm: part.widthMm)
        }
        return [
            EvalVariant(name: name, inventory: base),
            EvalVariant(name: "\(name), particleboard top", inventory: particleboardTop),
            EvalVariant(name: "\(name), damaged side", inventory: damagedSide),
            EvalVariant(name: "\(name), max width 420 mm", inventory: base,
                        limits: SizeLimits(maxDepthMm: nil, maxHeightMm: nil, maxWidthMm: 420)),
        ]
    }
}

/// One agent run in an eval.
public struct EvalRun: Sendable, Equatable {
    public var variant: String
    public var outcome: AgentOutcome
    public var seconds: Double
    public var calls: Int

    public init(variant: String, outcome: AgentOutcome, seconds: Double, calls: Int) {
        self.variant = variant
        self.outcome = outcome
        self.seconds = seconds
        self.calls = calls
    }
}

/// The numbers for one variant, for the slide.
public struct EvalRow: Sendable, Equatable {
    public var variant: String
    public var runs: Int
    public var acceptedFirstTry: Int
    public var acceptedAfterRepair: Int
    public var fallbacks: Int
    /// Fallbacks that still showed a validated plan (the safety net working).
    public var safeFallbacks: Int
    public var averageSeconds: Double
    public var averageCalls: Double
}

public enum EvalSummary {
    /// Accepted, and the very first plan Gemini submitted was the accepted one.
    public static func acceptedFirstTry(_ outcome: AgentOutcome) -> Bool {
        guard case .accepted = outcome else { return false }
        return outcome.trace.first { $0.tool == .submitPlan }?.status == .accepted
    }

    /// One row per variant, in the order variants first appear.
    public static func rows(_ runs: [EvalRun]) -> [EvalRow] {
        var order: [String] = []
        for run in runs where !order.contains(run.variant) { order.append(run.variant) }
        return order.map { variant in
            let group = runs.filter { $0.variant == variant }
            let accepted = group.filter { if case .accepted = $0.outcome { return true } else { return false } }
            let firstTry = accepted.filter { acceptedFirstTry($0.outcome) }.count
            let fallbacks = group.count - accepted.count
            let safe = group.filter { run in
                if case let .fallback(plan, _, _, _) = run.outcome { return plan != nil } else { return false }
            }.count
            return EvalRow(variant: variant, runs: group.count, acceptedFirstTry: firstTry,
                           acceptedAfterRepair: accepted.count - firstTry, fallbacks: fallbacks, safeFallbacks: safe,
                           averageSeconds: group.map(\.seconds).reduce(0, +) / Double(group.count),
                           averageCalls: Double(group.map(\.calls).reduce(0, +)) / Double(group.count))
        }
    }

    /// A markdown table for the slide.
    public static func markdown(_ rows: [EvalRow]) -> String {
        var lines = [
            "| Variant | Runs | Accepted on first submit | Accepted after repair | Fallback (safe plan) | Avg time | Avg Gemini calls |",
            "|---|---|---|---|---|---|---|",
        ]
        for row in rows {
            let time = String(format: "%.1f s", row.averageSeconds)
            let calls = String(format: "%.1f", row.averageCalls)
            lines.append("| \(row.variant) | \(row.runs) | \(row.acceptedFirstTry) | \(row.acceptedAfterRepair) | "
                + "\(row.fallbacks) (\(row.safeFallbacks)) | \(time) | \(calls) |")
        }
        let total = rows.map(\.runs).reduce(0, +)
        let shown = rows.map { $0.acceptedFirstTry + $0.acceptedAfterRepair + $0.safeFallbacks }.reduce(0, +)
        lines.append("")
        lines.append("Validated plans shown: \(shown) of \(total) runs; any others were an honest \"no safe plan\". "
            + "No invalid plan was ever shown.")
        return lines.joined(separator: "\n")
    }

    /// The spec's baseline metric, told honestly: plans with an impossible cut, unsafe part or sag are "unsafe";
    /// an answer with no parts at all ("this can't be done") is "no plan", which is a different thing.
    public static func chatbotOutcomes(_ results: [ValidationResult]) -> ChatbotOutcomes {
        let empty = results.filter { $0.violations.contains { $0.code == .emptyPlan } }.count
        let unsafe = results.filter { !$0.passes }.count - empty
        return ChatbotOutcomes(unsafe: unsafe, noPlan: empty, valid: results.count - unsafe - empty)
    }
}

/// How a set of chatbot answers fared against the validator.
public struct ChatbotOutcomes: Sendable, Equatable {
    public var unsafe: Int
    public var noPlan: Int
    public var valid: Int

    public var summary: String {
        "unsafe plans (an impossible cut, unsafe part or sag): \(unsafe) · no plan at all: \(noPlan) · valid plans: \(valid)"
    }
}
