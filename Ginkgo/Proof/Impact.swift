import Foundation
import GinkgoCore

/// What a plan reuses, for the Ideas cards. Every value is computed from the measured parts and the
/// validated plan; nothing rests on a guessed price or a typical density.
struct Impact: Equatable {
    /// Share of the old furniture's panel area the plan reuses, from the validator.
    let reusePercent: Double
    /// Area of material the plan reuses, in m², from the measured part sizes.
    let reusedAreaM2: Double
    /// Pieces that have to be cut; zero for a plan that reuses parts whole.
    let cuts: Int
    static func of(plan: Plan, inventory: Inventory, result: ValidationResult) -> Impact {
        let known = plan.newParts.filter { part in inventory.parts.contains { $0.id == part.sourcePartID } }
        let area = known.reduce(0) { $0 + $1.widthMm * $1.heightMm / 1_000_000 }
        return Impact(reusePercent: result.reusePercent, reusedAreaM2: area,
                      cuts: plan.template == .noCut ? 0 : known.count)
    }

    var difficulty: String {
        switch cuts {
        case 0: return "No cuts: reuse the parts whole"
        case 1: return "1 cut"
        default: return "\(cuts) cuts"
        }
    }

    /// "70% reused · 0.42 m² of material"
    var summary: String {
        String(format: "%.0f%% reused · %.2f m² of material", reusePercent, reusedAreaM2)
    }
}

/// The builds offered for a parts list. Only wood and plywood are cut, so parts made only of plastic,
/// cardboard or MDF get one honest idea: reuse them as they are.
enum Idea: String, CaseIterable, Identifiable {
    case bench, bookshelf, reuseAsIs
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bench: return "Bench"
        case .bookshelf: return "Bookshelf"
        case .reuseAsIs: return "Reuse it as it is"
        }
    }

    var request: String {
        switch self {
        case .bench: return Prompts.defaultRequest
        case .bookshelf: return "Make a bookshelf."
        case .reuseAsIs: return "Reuse the parts whole, with no cuts."
        }
    }

    var icon: String {
        switch self {
        case .bench: return "chair.lounge"
        case .bookshelf: return "books.vertical"
        case .reuseAsIs: return "arrow.3.trianglepath"
        }
    }

    /// Whether any part can be cut: only solid wood and plywood are.
    static func canCut(_ inventory: Inventory) -> Bool {
        inventory.parts.contains { !$0.damaged && ($0.material == .solidWood || $0.material == .plywood) }
    }

    /// The ideas that make sense for these parts.
    static func options(for inventory: Inventory) -> [Idea] {
        canCut(inventory) ? [.bench, .bookshelf] : [.reuseAsIs]
    }

    static let noCutReason = "Plastic, cardboard and MDF aren't cut: they lose strength and hold screws poorly. "
        + "Ginkgo plans to reuse these parts whole."
}
