import Foundation
import GinkgoCore

/// "Verify before you cut": re-measure the dimensions the plan depends on most and re-check the plan with
/// Vivek's Verifier: verified, adjusted to the real size, or withdrawn. A person still makes the final call.
struct VerifyModel {
    enum Status: Equatable {
        /// Some checks still need measuring.
        case pending(remaining: Int)
        /// Every check measured and the plan passes as it is.
        case verified
        /// Every check measured; the plan was resized to fit the real measurements. The string says why.
        case adjusted(String)
        /// The real numbers break the plan and nothing of the same kind fits; don't cut.
        case withdrawn([String])
    }

    /// The most checks asked for; the spec's "2–3 measurements it depends on most".
    static let maxChecks = 3

    private(set) var plan: Plan
    let checks: [VerifyItem]
    private(set) var inventory: Inventory
    private(set) var result: ValidationResult
    /// Measured sizes in mm, by check index.
    private(set) var measured: [Int: Double] = [:]
    private var adjustment: String?
    private var withdrawal: String?

    init(plan: Plan, inventory: Inventory, result: ValidationResult) {
        self.plan = plan
        self.inventory = inventory
        self.result = result
        checks = Array(result.verify.sorted { $0.marginMm < $1.marginMm }.prefix(Self.maxChecks))
    }

    var status: Status {
        if let withdrawal { return .withdrawn([withdrawal]) }
        let remaining = checks.indices.filter { measured[$0] == nil }.count
        if remaining > 0 { return .pending(remaining: remaining) }
        return adjustment.map { .adjusted($0) } ?? .verified
    }

    /// Steps and hardware are shown only once every check is measured and the plan holds, as is or adjusted.
    var isBuildable: Bool {
        switch status {
        case .verified, .adjusted: return true
        case .pending, .withdrawn: return false
        }
    }

    /// What to measure, in words: "The top's width".
    func title(of index: Int) -> String {
        let check = checks[index]
        return "The \(ProofModel.displayName(check.sourcePartID).lowercased())'s \(check.dimension.rawValue)"
    }

    /// The size the plan currently assumes for a check, in mm.
    func planned(_ index: Int) -> Double? {
        let check = checks[index]
        guard let part = inventory.parts.first(where: { $0.id == check.sourcePartID }) else { return nil }
        switch check.dimension {
        case .width: return part.widthMm
        case .height: return part.heightMm
        case .thickness: return part.thicknessMm
        }
    }

    /// Replaces the estimate with a real measurement and re-checks the plan against it.
    mutating func record(_ millimeters: Double, for index: Int) {
        guard checks.indices.contains(index), millimeters > 0, millimeters.isFinite else { return }
        let check = checks[index]
        let remeasured = Remeasurement(sourcePartID: check.sourcePartID, dimension: check.dimension, valueMm: millimeters)
        let outcome = Verifier.recheck(plan: plan, inventory: inventory, limits: nil, measured: remeasured)
        inventory = inventory.with(parts: inventory.parts.map {
            $0.id == check.sourcePartID ? Verifier.resized($0, remeasured) : $0
        })
        measured[index] = millimeters
        switch outcome {
        case .verified(_, let validation):
            result = validation
            withdrawal = nil
        case .adjusted(let newPlan, let validation, let reason):
            plan = newPlan
            result = validation
            adjustment = reason
            withdrawal = nil
        case .withdrawn(let reason):
            withdrawal = reason
        }
    }
}
