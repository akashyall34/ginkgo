import Foundation

/// The safety net: a bench built by fixed rules when the AI can't produce an accepted plan.
/// It only ever returns a plan that passes the validator, or nil. It never returns a failing plan.
public enum RuleBasedPlanner {
    public static let planID = "plan-fallback"
    static let step = 10.0
    static let minSeatSize = 200.0
    static let maxSupportHeight = 420.0
    static let minSupportHeight = 300.0
    static let screw = "wood screw, 40 mm"

    /// A validated bench from the undamaged parts; if that fails, the parts reused whole (no cuts); otherwise nil.
    public static func bench(inventory: Inventory, limits: SizeLimits? = nil) -> (plan: Plan, validation: ValidationResult)? {
        let usable = inventory.parts.filter { !$0.damaged }
        guard !usable.isEmpty else { return nil }
        let cuttable = usable.filter { $0.material != .particleboardMDF }
        if let draft = benchDraft(from: cuttable), let accepted = accept(draft, inventory: inventory, limits: limits) {
            return accepted
        }
        return accept(noCutDraft(from: usable), inventory: inventory, limits: limits)
    }

    static func accept(_ draft: PlanDraft, inventory: Inventory, limits: SizeLimits?) -> (plan: Plan, validation: ValidationResult)? {
        let plan = Layout.plan(from: draft, inventory: inventory, id: planID)
        let validation = Validator.validate(plan: plan, inventory: inventory, limits: limits)
        return validation.passes ? (plan, validation) : nil
    }

    // MARK: - Bench

    static func benchDraft(from cuttable: [Part]) -> PlanDraft? {
        guard let seatSource = cuttable.first(where: { $0.type == .top }) ?? largestFirst(cuttable).first,
              let seat = seatSize(on: seatSource) else { return nil }
        let supports = supportSources(from: cuttable, excluding: seatSource.id)
        guard supports.count == 2, let leg = supportSize(on: supports, seatDepth: seat.depth) else { return nil }
        let span = seat.width - supports[0].thicknessMm - supports[1].thicknessMm
        guard span > 0 else { return nil }

        let parts = [
            DraftPart(heightMm: seat.depth, name: "seat", role: .seat, sourcePartID: seatSource.id, spanMm: span,
                      widthMm: seat.width),
            DraftPart(heightMm: leg.height, name: "leg_left", role: .support, sourcePartID: supports[0].id, spanMm: nil,
                      widthMm: leg.width),
            DraftPart(heightMm: leg.height, name: "leg_right", role: .support, sourcePartID: supports[1].id, spanMm: nil,
                      widthMm: leg.width),
        ]
        let legSize = "\(Format.mm(leg.width)) × \(Format.mm(leg.height)) mm"
        let steps = [
            "Cut the seat, \(Format.mm(seat.width)) × \(Format.mm(seat.depth)) mm, from the \(seatSource.id), clear of any screw holes.",
            "Cut leg_left from the \(supports[0].id) and leg_right from the \(supports[1].id), each \(legSize).",
            "Stand the legs upright under the ends of the seat, flush with its edges.",
            "Screw the seat to each leg with 4 wood screws, 40 mm.",
        ]
        return PlanDraft(hardware: [HardwareItem(item: screw, quantity: 8)], newParts: parts, steps: steps, template: .bench)
    }

    /// Largest seat that fits: starts at the panel minus the margin (longer side as width), then makes it
    /// 10 mm shallower until it fits; below 200 mm deep, starts again 10 mm narrower.
    static func seatSize(on source: Part) -> (width: Double, depth: Double)? {
        let startWidth = max(source.widthMm, source.heightMm) - Packer.margin
        let startDepth = min(source.widthMm, source.heightMm) - Packer.margin
        var width = startWidth
        while width >= minSeatSize {
            var depth = startDepth
            while depth >= minSeatSize {
                if fits(width, depth, on: source) { return (width, depth) }
                depth -= step
            }
            width -= step
        }
        return nil
    }

    /// The two parts of type side; otherwise the two largest other parts.
    static func supportSources(from cuttable: [Part], excluding seatID: String) -> [Part] {
        let others = cuttable.filter { $0.id != seatID }
        let sides = others.filter { $0.type == .side }
        return Array((sides.count >= 2 ? sides : largestFirst(others)).prefix(2))
    }

    /// Matching legs: as wide as the seat is deep (if the part allows) and up to 420 mm tall,
    /// then 10 mm shorter at a time, down to 300 mm, until both legs fit.
    static func supportSize(on parts: [Part], seatDepth: Double) -> (width: Double, height: Double)? {
        let width = parts.map { min(seatDepth, min($0.widthMm, $0.heightMm) - Packer.margin) }.min() ?? 0
        var height = parts.map { min(maxSupportHeight, max($0.widthMm, $0.heightMm) - Packer.margin) }.min() ?? 0
        guard width > 0 else { return nil }
        while height >= minSupportHeight {
            if parts.allSatisfy({ fits(width, height, on: $0) }) { return (width, height) }
            height -= step
        }
        return nil
    }

    static func fits(_ width: Double, _ height: Double, on source: Part) -> Bool {
        Packer.pack(source: source, cuts: [CutRequest(name: "test", widthMm: width, heightMm: height)]).failures.isEmpty
    }

    /// Largest area first; ties by ID.
    static func largestFirst(_ parts: [Part]) -> [Part] {
        parts.sorted { lhs, rhs in
            let (left, right) = (lhs.widthMm * lhs.heightMm, rhs.widthMm * rhs.heightMm)
            return left != right ? left > right : lhs.id < rhs.id
        }
    }

    // MARK: - No cut

    /// Every undamaged part reused whole, as a cubby or panel. Safe even for particleboard.
    static func noCutDraft(from usable: [Part]) -> PlanDraft {
        let parts = usable.map { part in
            DraftPart(heightMm: part.heightMm, name: part.id, role: .other, sourcePartID: part.id, spanMm: nil,
                      widthMm: part.widthMm)
        }
        let screws = 2 * (parts.count - 1)
        let steps = [
            "Clean each part and check it for loose veneer or splinters.",
            "Stand the parts side by side as cubbies or panels, without cutting them.",
            "If you want them to stay together, join each neighbouring pair with 2 wood screws, 40 mm.",
        ]
        let hardware = screws > 0 ? [HardwareItem(item: screw, quantity: screws)] : []
        return PlanDraft(hardware: hardware, newParts: parts, steps: steps, template: .noCut)
    }
}
