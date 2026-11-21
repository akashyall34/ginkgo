import Foundation
import GinkgoCore

/// "Verify before you cut": re-measure the dimensions the plan depends on most, re-run the validator
/// on the real numbers, and only then call the plan Verified. A person still makes the final call.
struct VerifyModel {
    enum Status: Equatable {
        /// Some checks still need measuring.
        case pending(remaining: Int)
        /// Every check measured and the plan still passes.
        case verified
        /// The real numbers break the plan; don't cut. The strings say why.
        case withdrawn([String])
    }

    /// The most checks asked for; the spec's "2–3 measurements it depends on most".
    static let maxChecks = 3

    let plan: Plan
    let checks: [VerifyItem]
    private(set) var inventory: Inventory
    private(set) var result: ValidationResult
    /// Measured sizes in mm, by check index.
    private(set) var measured: [Int: Double] = [:]

    init(plan: Plan, inventory: Inventory, result: ValidationResult) {
        self.plan = plan
        self.inventory = inventory
        self.result = result
        checks = Array(result.verify.sorted { $0.marginMm < $1.marginMm }.prefix(Self.maxChecks))
    }

    var status: Status {
        if !result.passes || !result.violations.isEmpty { return .withdrawn(result.violations.map(\.message)) }
        let remaining = checks.indices.filter { measured[$0] == nil }.count
        return remaining == 0 ? .verified : .pending(remaining: remaining)
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
        return check.dimension == .width ? part.widthMm : part.heightMm
    }

    /// Replaces the estimate with a real measurement and re-validates the same plan against it.
    mutating func record(_ millimeters: Double, for index: Int) {
        guard checks.indices.contains(index), millimeters > 0, millimeters.isFinite else { return }
        let check = checks[index]
        let parts = inventory.parts.map { part -> Part in
            guard part.id == check.sourcePartID else { return part }
            return check.dimension == .width ? part.with(widthMm: millimeters) : part.with(heightMm: millimeters)
        }
        inventory = inventory.with(parts: parts)
        measured[index] = millimeters
        result = Validator.validate(plan: plan, inventory: inventory, limits: nil)
    }
}
