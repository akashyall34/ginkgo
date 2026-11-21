import Foundation

/// Bad numbers for the sag check. Becomes a violation or a tool error, never a crash or NaN.
public enum SagError: Error, Equatable, Sendable {
    case invalidSize(String)

    public var message: String {
        switch self {
        case let .invalidSize(message): return message
        }
    }
}

/// Will a seat or shelf bend too much? Uniform load on a simply supported panel:
/// δ = 5·w·L⁴ / (384·E·I), with I = b·t³/12 and w = load × 9.81 / L (N/mm).
/// Passes when δ ≤ L / 600 (the spec's "0.02 in per foot of span").
public enum Sag {
    static let gravity = 9.81

    /// Stiffness E in N/mm² (MPa). Conservative defaults, kept in this one place.
    /// Still to do before the demo: cross-check against the Sagulator and the USDA Wood Handbook (CLAUDE.md setup step 9).
    public static func stiffness(of material: Material) -> Double {
        switch material {
        case .solidWood: return 9000
        case .plywood: return 7000
        case .particleboardMDF: return 2500
        case .plastic: return 1200     // polypropylene storage carts; conservative
        case .cardboard: return 200    // corrugated board; never load-bearing in practice
        }
    }

    /// The design load in kg for a role, or nil when the role isn't sag-checked.
    public static func designLoadKg(for role: Role) -> Double? {
        switch role {
        case .seat: return 100
        case .shelf: return 30
        case .side, .support, .back, .other: return nil
        }
    }

    /// Mid-span deflection in mm. Throws for any length that isn't a positive number.
    public static func deflection(loadKg: Double, spanMm: Double, depthMm: Double, thicknessMm: Double,
                                  stiffness: Double) throws -> Double {
        try requirePositive(spanMm, "span", unit: "mm")
        try requirePositive(depthMm, "depth", unit: "mm")
        try requirePositive(thicknessMm, "thickness", unit: "mm")
        try requirePositive(stiffness, "stiffness", unit: "N/mm²")
        guard loadKg.isFinite, loadKg >= 0 else { throw SagError.invalidSize("load must be 0 kg or more") }
        let loadPerMm = loadKg * gravity / spanMm
        let inertia = depthMm * pow(thicknessMm, 3) / 12
        return 5 * loadPerMm * pow(spanMm, 4) / (384 * stiffness * inertia)
    }

    /// The largest deflection allowed for a span, in mm.
    public static func limit(spanMm: Double) -> Double {
        spanMm / 600 // MUTANT:sag-limit
    }

    /// Checks one seat or shelf cut from `source` (its thickness and material set the stiffness).
    /// Returns nil for roles that carry no load (side, support, back, other).
    public static func check(name: String, role: Role, spanMm: Double, depthMm: Double,
                             source: Part) throws -> SagResult? {
        guard let loadKg = designLoadKg(for: role) else { return nil }
        let bend = try deflection(loadKg: loadKg, spanMm: spanMm, depthMm: depthMm,
                                  thicknessMm: source.thicknessMm, stiffness: stiffness(of: source.material))
        let allowed = limit(spanMm: spanMm)
        return SagResult(deflectionMm: bend, limitMm: allowed, newPart: name, passes: bend <= allowed, spanMm: spanMm)
    }

    /// Checks a part of a plan: span is `span_mm` (or the width when it's missing), depth is the part's height.
    public static func check(_ part: NewPart, source: Part) throws -> SagResult? {
        try check(name: part.name, role: part.role, spanMm: part.spanMm ?? part.widthMm,
                  depthMm: part.heightMm, source: source)
    }

    static func requirePositive(_ value: Double, _ name: String, unit: String) throws {
        guard value.isFinite, value > 0 else {
            throw SagError.invalidSize("\(name) must be more than 0 \(unit), got \(Format.mm(value))")
        }
    }
}
