import Foundation

/// Solid wood is far stiffer along its grain than across it. A seat or shelf spanning across the grain, or on a
/// panel whose grain hasn't been confirmed, is rated with the across-grain stiffness, so no plan is proven on a guess.
public enum WoodGrain {
    /// Across-grain stiffness as a share of along-grain: the lowest ET/EL among furniture woods in the table, basswood.
    /// (Balsa is lower, 0.015, but isn't a furniture wood.) Red oak is 0.082, Douglas-fir 0.050.
    public static let acrossGrainRatio = 0.027
    public static let source = "USDA Forest Products Laboratory, Wood Handbook, FPL-GTR-282 (2021), Table 5-1, "
        + "elastic ratios at about 12% moisture content: ET/EL"

    /// The share of the material's stiffness a seat or shelf gets. Its span runs along its own width; `rotated` means
    /// that width runs along the panel's height in the cutting diagram. A piece that couldn't be placed (nil) is
    /// judged as planned, unrotated: it is already rejected for not fitting.
    public static func stiffnessFactor(source: Part, rotated: Bool?) -> Double {
        guard source.material == .solidWood else { return 1 }
        guard let grain = source.grain else { return acrossGrainRatio }
        let spanAlongPanelWidth = !(rotated ?? false)
        let alongGrain = (grain == .alongWidth) == spanAlongPanelWidth
        return alongGrain ? 1 : acrossGrainRatio
    }
}
