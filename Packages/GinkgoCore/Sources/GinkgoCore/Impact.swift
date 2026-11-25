import Foundation

/// The EPA figures behind "Less landfill", with their source. Nothing else on the impact screen is a statistic: the
/// rest is computed from the person's own plan.
public enum ImpactFacts {
    /// The latest year EPA publishes furniture figures for (checked on EPA's page, last updated Oct 19, 2026).
    public static let year = 2018
    /// "Furniture and furnishings" generated in US municipal solid waste, thousand US tons (EPA table).
    public static let generatedThousandTons = 12_080.0
    /// Of that, landfilled, thousand US tons (EPA table).
    public static let landfilledThousandTons = 9_680.0
    public static let sourceName = "EPA, Durable Goods: Product-Specific Data (2018 data)"
    public static let sourceURL =
        "https://www.epa.gov/facts-and-figures-about-materials-waste-and-recycling/durable-goods-product-specific-data"

    /// The landfilled share of generation, to 0.1%: EPA states 80.1%.
    public static var landfillShare: Double { (landfilledThousandTons / generatedThousandTons * 1000).rounded() / 10 }

    /// Landfilled million tons, to 0.1.
    public static var landfilledMillionTons: Double { (landfilledThousandTons / 100).rounded() / 10 }

    /// "In 2018 the US landfilled 9.7 million tons of furniture: 80.1% of what it generated."
    public static var sentence: String {
        String(format: "In %d the US landfilled %.1f million tons of furniture: %.1f%% of what it generated.",
               year, landfilledMillionTons, landfillShare)
    }
}

/// What a plan keeps out of the trash, from the plan itself: areas and panel counts, never weights (weight needs
/// the wood's density, which Ginkgo doesn't guess). Only a plan that passed the validator makes a claim.
public struct ImpactSummary: Equatable, Sendable {
    public let reusedAreaM2: Double
    public let totalAreaM2: Double
    public let reusePercent: Double
    public let panelsUsed: Int
    public let panelsTotal: Int

    /// Nil unless the validator accepted the plan.
    public init?(plan: Plan, validation: ValidationResult, inventory: Inventory) {
        guard validation.passes else { return nil }
        func area(_ width: Double, _ height: Double) -> Double {
            let value = width * height
            return value.isFinite && value > 0 ? value : 0
        }
        reusedAreaM2 = plan.newParts.reduce(0) { $0 + area($1.widthMm, $1.heightMm) } / 1_000_000
        totalAreaM2 = inventory.parts.reduce(0) { $0 + area($1.widthMm, $1.heightMm) } / 1_000_000
        reusePercent = validation.reusePercent
        panelsUsed = Set(validation.placements.map(\.sourcePartID)).count
        panelsTotal = inventory.parts.count
    }

    /// "72% of the wood stays in use".
    public var headline: String { String(format: "%.0f%% of the wood stays in use", reusePercent) }

    /// "0.42 m² of panel reused, out of 0.58 m² in your piece".
    public var areaLine: String {
        String(format: "%.2f m² of panel reused, out of %.2f m² in your piece", reusedAreaM2, totalAreaM2)
    }

    /// "3 of 4 panels used".
    public var panelsLine: String {
        panelsTotal == 1 ? "\(panelsUsed) of 1 panel used" : "\(panelsUsed) of \(panelsTotal) panels used"
    }

    public static let note = "Measured in area, not weight: weight depends on the wood, which Ginkgo doesn't guess."
}
