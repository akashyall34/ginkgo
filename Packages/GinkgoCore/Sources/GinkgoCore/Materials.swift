import Foundation

/// Everything Ginkgo knows about one material, in one place. The validator, the sag check, the fallback planner
/// and Gemini's prompts all read this table, so they can never disagree. Numbers come from code, never from the AI.
public struct MaterialInfo: Sendable, Equatable {
    public var material: Material
    public var displayName: String
    /// Whether Ginkgo's plans may cut it. A whole-part reuse is always allowed.
    public var canBeCut: Bool
    /// Finishes "<part> is <material>, which ...".
    public var whyNotCut: String
    /// Stiffness E in N/mm² (MPa) for the sag check. Conservative on purpose.
    public var stiffness: Double
    /// What joins parts of this material.
    public var fastener: String
    /// A whole-part reuse idea, for the prompt and the no-cut plan.
    public var reuseIdea: String
    /// Where the stiffness comes from.
    public var source: String
    /// A typical panel or wall thickness, assumed until the user confirms it.
    public var typicalThicknessMm: Double = 18
}

public enum MaterialCatalog {
    public static let all: [MaterialInfo] = [
        MaterialInfo(material: .solidWood, displayName: "solid wood", canBeCut: true, whyNotCut: "can be cut",
                     stiffness: 9000, fastener: "wood screw, 40 mm", reuseIdea: "cut into benches and shelves",
                     source: "USDA Wood Handbook: softwoods about 8,000-12,000 N/mm²; low end used"),
        MaterialInfo(material: .plywood, displayName: "plywood", canBeCut: true, whyNotCut: "can be cut",
                     stiffness: 7000, fastener: "wood screw, 40 mm", reuseIdea: "cut into benches and shelves",
                     source: "USDA Wood Handbook: plywood about 7,000-10,000 N/mm² along the face grain"),
        MaterialInfo(material: .particleboardMDF, displayName: "particleboard/MDF", canBeCut: false, whyNotCut: "crumbles when cut",
                     stiffness: 2500, fastener: "wood screw, 40 mm", reuseIdea: "reuse panels whole as shelves or cubbies",
                     source: "Manufacturer data: MDF about 2,500-4,000 N/mm²; particleboard about 2,000-3,000"),
        MaterialInfo(material: .plastic, displayName: "plastic", canBeCut: false,
                     whyNotCut: "has thin walls that crack or warp when sawn",
                     stiffness: 1200, fastener: "cable tie, 200 mm",
                     reuseIdea: "reuse drawers and bins whole as cubbies or organizers",
                     source: "Polypropylene datasheets: about 1,300-1,800 N/mm²; rounded down", typicalThicknessMm: 3),
        MaterialInfo(material: .cardboard, displayName: "cardboard", canBeCut: false,
                     whyNotCut: "is too weak to cut into furniture parts",
                     stiffness: 200, fastener: "double-sided mounting tape strip",
                     reuseIdea: "reuse whole as light storage, never load-bearing",
                     source: "Corrugated board bends easily; a deliberately low value so it never passes as a seat or shelf",
                     typicalThicknessMm: 4),
    ]

    public static func info(_ material: Material) -> MaterialInfo {
        all.first { $0.material == material } ?? all[0]
    }

    /// The materials section of Gemini's prompts, generated from this table.
    public static var promptLines: String {
        all.map { info in
            let rule = info.canBeCut ? "may be cut" : "never cut, reuse whole (\(info.whyNotCut))"
            return "- \(info.material.rawValue): \(rule); stiffness \(Int(info.stiffness)) N/mm²; join with \(info.fastener); "
                + "idea: \(info.reuseIdea)."
        }.joined(separator: "\n")
    }

    /// The fastener for a set of parts: the weakest (least stiff) material decides.
    public static func fastener(for materials: [Material]) -> String {
        let weakest = materials.map(info).min { $0.stiffness < $1.stiffness }
        return (weakest ?? info(.solidWood)).fastener
    }
}

public extension Material {
    var canBeCut: Bool { MaterialCatalog.info(self).canBeCut }
    var displayName: String { MaterialCatalog.info(self).displayName }
    var whyNotCut: String { MaterialCatalog.info(self).whyNotCut }
}
