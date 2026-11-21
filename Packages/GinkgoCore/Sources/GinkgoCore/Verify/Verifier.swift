import Foundation

/// One measurement the user re-took before cutting (screen 6, "Verify").
public struct Remeasurement: Sendable, Equatable {
    public var sourcePartID: String
    public var dimension: Dimension
    public var valueMm: Double

    public init(sourcePartID: String, dimension: Dimension, valueMm: Double) {
        self.sourcePartID = sourcePartID
        self.dimension = dimension
        self.valueMm = valueMm
    }
}

/// What a re-measurement does to a plan.
public enum VerifyOutcome: Sendable, Equatable {
    /// The same plan still passes with the real size.
    case verified(plan: Plan, validation: ValidationResult)
    /// The plan no longer fits, but a plan of the same kind does.
    case adjusted(plan: Plan, validation: ValidationResult, reason: String)
    /// Nothing of the same kind fits any more.
    case withdrawn(reason: String)
}

/// Trust before anyone cuts: re-runs the validator with the re-measured size. Offline, deterministic.
public enum Verifier {
    public static func recheck(plan: Plan, inventory: Inventory, limits: SizeLimits?, measured: Remeasurement) -> VerifyOutcome {
        guard measured.valueMm.isFinite, measured.valueMm > 0 else {
            return .withdrawn(reason: "The new measurement must be more than 0 mm.")
        }
        guard inventory.parts.contains(where: { $0.id == measured.sourcePartID }) else {
            return .withdrawn(reason: "There is no part \"\(measured.sourcePartID)\" to re-measure.")
        }
        let updated = Inventory(parts: inventory.parts.map { $0.id == measured.sourcePartID ? resized($0, measured) : $0 },
                                scanID: inventory.scanID)
        let validation = Validator.validate(plan: plan, inventory: updated, limits: limits)
        if validation.passes { return .verified(plan: plan, validation: validation) }

        let problems = validation.violations.map(\.message).joined(separator: " ")
        if let safe = RuleBasedPlanner.bench(inventory: updated, limits: limits), safe.plan.template == plan.template {
            return .adjusted(plan: safe.plan, validation: safe.validation,
                             reason: "The new measurement changes the plan. \(problems)")
        }
        return .withdrawn(reason: "\(problems) No \(plan.template.rawValue) fits the new measurement.")
    }

    static func resized(_ part: Part, _ measured: Remeasurement) -> Part {
        let width = measured.dimension == .width ? measured.valueMm : part.widthMm
        let height = measured.dimension == .height ? measured.valueMm : part.heightMm
        return Part(damaged: part.damaged, heightMm: height, id: part.id, keepOuts: part.keepOuts, material: part.material,
                    thicknessMm: part.thicknessMm, type: part.type, widthMm: width)
    }
}
