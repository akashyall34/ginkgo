import Foundation

/// One assembly step: what to do, and which pieces are in place once it's done (for the 3D view).
public struct AssemblyStep: Sendable, Equatable {
    public var text: String
    /// Every piece placed by the end of this step, in plan order.
    public var placed: [String]
}

/// A screw for the brackets, sized to the thinnest panel it goes into.
public struct ScrewSpec: Sendable, Equatable {
    /// "#8 × 5/8 in" and its length in mm.
    public var label: String
    public var lengthMm: Double
    /// Pilot hole advice for the material, from the ANSI B18.6.1 table for #8 screws.
    public var pilotHole: String
}

/// How to put the build together, from tested rules: no AI decides a size, a count or a screw.
/// Joints use steel corner brackets screwed into the panels' faces: the NDS screw provisions don't cover fastening
/// into end grain, which is what a screw down into a support's top edge would usually hit.
public enum AssemblyGuide {
    /// #8 wood screw stock lengths, inches → mm.
    public static let screwLengths: [(label: String, mm: Double)] = [("1/2 in", 12.7), ("5/8 in", 15.9),
                                                                     ("3/4 in", 19.1), ("1 in", 25.4)]
    /// A screw this much shorter than the panel never pokes through the other face (Woodcraft: choose a length that
    /// engages well without poking through).
    public static let throughClearanceMm = 3.0
    /// Brackets per joint, set this far in from the front and back edges. Ginkgo's choice, stated as such.
    public static let bracketsPerJoint = 2
    public static let bracketInsetMm = 40.0
    public static let screwsPerBracket = 4
    public static let bracket = "steel corner bracket, 40 × 40 mm, 4 holes"

    /// The longest stock #8 screw that stays inside a panel this thick; nil if even the shortest would poke through.
    public static func screw(forThicknessMm thickness: Double, material: Material) -> ScrewSpec? {
        // A thousandth of a mm of slack, so a panel exactly at the limit (18.9 mm for 5/8 in) isn't lost to rounding.
        guard let fit = screwLengths.last(where: { $0.mm <= thickness - throughClearanceMm + 0.001 }) else { return nil }
        return ScrewSpec(label: "#8 × \(fit.label)", lengthMm: fit.mm, pilotHole: pilotHole(for: material))
    }

    /// ANSI B18.6.1 pilot holes for #8 screws: 5/64 in in softwood, 3/32 in in hardwood. A species isn't known from a
    /// scan, so the softwood size leads and the hardwood size is named. No source gives particleboard a figure.
    public static func pilotHole(for material: Material) -> String {
        switch material {
        case .solidWood, .plywood:
            return "Drill 5/64 in pilot holes (3/32 in if the wood is hard, like oak or maple)."
        case .particleboardMDF:
            return "Particleboard splits easily: drill a test pilot hole in a scrap first, starting at 5/64 in."
        case .plastic, .cardboard:
            return "This material doesn't hold screws: use it only where nothing is fastened to it."
        }
    }

    public struct Guide: Sendable, Equatable {
        public var steps: [AssemblyStep]
        public var hardware: [HardwareItem]
        /// Why a joint can't be screwed (a panel too thin): shown instead of pretending it can.
        public var warnings: [String]
    }

    public static func guide(for plan: Plan, inventory: Inventory) -> Guide {
        if plan.template == .noCut {
            return Guide(steps: [AssemblyStep(text: "Nothing to build: each panel is reused as it is.",
                                              placed: plan.newParts.map(\.name))], hardware: [], warnings: [])
        }
        let parts = inventory.partsByID
        let tops = plan.newParts.filter { $0.role == .seat || $0.role == .shelf }
        let uprights = plan.newParts.filter { $0.role == .support || $0.role == .side }
        guard let top = tops.first, !uprights.isEmpty else {
            return Guide(steps: [AssemblyStep(text: "Join the pieces as shown in the 3D view.",
                                              placed: plan.newParts.map(\.name))],
                         hardware: [], warnings: ["This plan has no seat or shelf on supports, so Ginkgo has no tested joint for it."])
        }

        var steps = [AssemblyStep(text: "Sand the cut edges smooth so nothing splinters.", placed: []),
                     AssemblyStep(text: "Lay the \(Format.partName(top.name)) upside down on a clean, flat floor.",
                                  placed: [top.name])]
        var placed = [top.name]
        var warnings: [String] = []
        var screwCounts: [String: Int] = [:]
        for upright in uprights {
            placed.append(upright.name)
            let thinnest = min(parts[top.sourcePartID]?.thicknessMm ?? 0, parts[upright.sourcePartID]?.thicknessMm ?? 0)
            let material = parts[upright.sourcePartID]?.material ?? .particleboardMDF
            let uprightThickness = parts[upright.sourcePartID]?.thicknessMm ?? 0
            steps.append(AssemblyStep(text: "Stand the \(Format.partName(upright.name)) on the "
                                        + "\(Format.partName(top.name))'s underside, "
                                        + "\(position(of: upright, thicknessMm: uprightThickness, on: top)), "
                                        + "square to it.", placed: placed))
            guard let screw = screw(forThicknessMm: thinnest, material: material) else {
                warnings.append("\(Format.partName(upright.name).capitalizedFirst): at \(Format.mm(thinnest)) mm "
                                + "the panel is too thin for a bracket screw. "
                                + "Glue and clamp this joint instead.")
                continue
            }
            steps.append(AssemblyStep(
                text: "Put \(bracketsPerJoint) brackets in the inside corner, \(Format.mm(bracketInsetMm)) mm in from the front "
                    + "and back edges. Mark the holes. \(screw.pilotHole) Drive \(screw.label) screws.",
                placed: placed))
            screwCounts[screw.label, default: 0] += bracketsPerJoint * screwsPerBracket
        }
        steps.append(AssemblyStep(text: "Turn it over onto its \(uprights.count == 1 ? "support" : "supports"). "
                                    + "Check it stands flat without rocking.", placed: placed))
        let joints = uprights.count - warnings.count
        var hardware = joints > 0 ? [HardwareItem(item: bracket, quantity: joints * bracketsPerJoint)] : []
        hardware += screwCounts.sorted { $0.key < $1.key }.map { HardwareItem(item: "wood screw, \($0.key)", quantity: $0.value) }
        return Guide(steps: steps, hardware: hardware, warnings: warnings)
    }

    /// "flush with its left end" or "12 mm in from its right end", from the plan's 3D layout.
    static func position(of upright: NewPart, thicknessMm thickness: Double, on top: NewPart) -> String {
        let topLeft = top.positionMm.x - top.widthMm / 2, topRight = top.positionMm.x + top.widthMm / 2
        let onLeft = upright.positionMm.x < top.positionMm.x
        let face = onLeft ? upright.positionMm.x - thickness / 2 : upright.positionMm.x + thickness / 2
        let inset = onLeft ? face - topLeft : topRight - face
        let end = onLeft ? "left" : "right"
        return abs(inset) < 1 ? "flush with its \(end) end" : "\(Format.mm(inset)) mm in from its \(end) end"
    }
}
