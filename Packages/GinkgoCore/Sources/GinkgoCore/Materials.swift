import Foundation

/// Everything Ginkgo knows about one material, in one place. The validator, the sag check, the fallback planner
/// and Gemini's prompts all read this table, so they can never disagree. Numbers come from code, never from the AI,
/// and every number has a source. A material without a sourced stiffness is never load-bearing.
public struct MaterialInfo: Sendable, Equatable {
    public var material: Material
    public var displayName: String
    /// Whether Ginkgo's plans may cut it. A whole-part reuse is always allowed.
    public var canBeCut: Bool
    /// Finishes "<part> is <material>, which ...".
    public var whyNotCut: String
    /// Stiffness E in N/mm² (MPa) for the sag check, or nil: then the material is never a seat or shelf.
    public var stiffness: Double?
    /// What joins parts of this material.
    public var fastener: String
    /// A whole-part reuse idea, for the prompt and the no-cut plan.
    public var reuseIdea: String
    /// Where the stiffness comes from, with the edition or date.
    public var source: String
    /// How and when the value was cross-checked.
    public var checked: String
    /// A typical panel or wall thickness, assumed until the user confirms it.
    public var typicalThicknessMm: Double = 18

    /// Load-bearing means it has a sourced stiffness, so seats and shelves made of it can be checked for sag.
    public var loadBearing: Bool { stiffness != nil }
}

public enum MaterialCatalog {
    /// The Sagulator (woodbin.com) run on 2026-11-21 with the same inputs (floating shelf, uniform total load); see docs/sag-check.md.
    static let woodChecked = "Sagulator (woodbin.com), Eastern white pine, 2026-11-21: within 6%, same verdict in 3 of 3 cases"
    static let plywoodChecked = "Sagulator (woodbin.com), fir plywood, 2026-11-21: ours 18% more sag, same verdict"
    static let boardChecked = "Sagulator (woodbin.com), M-2 particleboard, 2026-11-21: ours 12% less sag, same verdict"

    public static let all: [MaterialInfo] = [
        MaterialInfo(material: .solidWood, displayName: "solid wood", canBeCut: true, whyNotCut: "can be cut",
                     stiffness: 9000, fastener: "wood screw, 40 mm", reuseIdea: "cut into benches and shelves",
                     source: "USDA Forest Products Laboratory, Wood Handbook, FPL-GTR-282 (2021), ch. 5: softwood MOE",
                     checked: woodChecked),
        MaterialInfo(material: .plywood, displayName: "plywood", canBeCut: true, whyNotCut: "can be cut",
                     stiffness: 7000, fastener: "wood screw, 40 mm", reuseIdea: "cut into benches and shelves",
                     source: "USDA Forest Products Laboratory, Wood Handbook, FPL-GTR-282 (2021): plywood",
                     checked: plywoodChecked),
        MaterialInfo(material: .particleboardMDF, displayName: "particleboard/MDF", canBeCut: false, whyNotCut: "crumbles when cut",
                     stiffness: 2500, fastener: "wood screw, 40 mm", reuseIdea: "reuse panels whole as shelves or cubbies",
                     source: "ANSI A208.1-2022 (particleboard) and A208.2-2022 (MDF) MOE grades; below a "
                        + "manufacturer's 155-grade MDF (over 600,000 psi, about 4,100 N/mm²)",
                     checked: boardChecked),
        MaterialInfo(material: .plastic, displayName: "plastic", canBeCut: false,
                     whyNotCut: "has thin walls that crack or warp when sawn",
                     stiffness: nil, fastener: "cable tie, 200 mm",
                     reuseIdea: "reuse drawers and bins whole as cubbies or organizers, never load-bearing",
                     source: "None used: hollow molded parts have no single stiffness; never a seat or shelf",
                     checked: "Rule, not a number (team trust audit, 2026-11-21)", typicalThicknessMm: 3),
        MaterialInfo(material: .cardboard, displayName: "cardboard", canBeCut: false,
                     whyNotCut: "is too weak to cut into furniture parts",
                     stiffness: nil, fastener: "double-sided mounting tape strip",
                     reuseIdea: "reuse whole as light storage, never load-bearing",
                     source: "None used: corrugated board's stiffness depends on its flutes, not one constant; never a seat or shelf",
                     checked: "Rule, not a number (team trust audit, 2026-11-21)", typicalThicknessMm: 4),
    ]

    public static func info(_ material: Material) -> MaterialInfo {
        all.first { $0.material == material } ?? all[0]
    }

    /// The materials section of Gemini's prompts, generated from this table.
    public static var promptLines: String {
        all.map { info in
            let rule = info.canBeCut ? "may be cut" : "never cut, reuse whole (\(info.whyNotCut))"
            let load = info.loadBearing ? "may carry load" : "never a seat or shelf (not load-bearing)"
            return "- \(info.material.rawValue): \(rule); \(load); join with \(info.fastener); idea: \(info.reuseIdea)."
        }.joined(separator: "\n")
    }

    /// Weakest first: the weakest material in a set decides how its parts are joined.
    static let weakestFirst: [Material] = [.cardboard, .plastic, .particleboardMDF, .plywood, .solidWood]

    /// The fastener for a set of parts: the weakest material decides.
    public static func fastener(for materials: [Material]) -> String {
        info(weakestFirst.first { materials.contains($0) } ?? .solidWood).fastener
    }
}

public extension Material {
    var canBeCut: Bool { MaterialCatalog.info(self).canBeCut }
    var displayName: String { MaterialCatalog.info(self).displayName }
    var whyNotCut: String { MaterialCatalog.info(self).whyNotCut }
}
