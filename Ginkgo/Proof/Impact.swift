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

/// The builds offered for a parts list.
enum Idea: String, CaseIterable, Identifiable {
    case bench, bookshelf
    var id: String { rawValue }

    var title: String { self == .bench ? "Bench" : "Bookshelf" }
    var request: String { self == .bench ? Prompts.defaultRequest : "Make a bookshelf." }
    var icon: String { self == .bench ? "chair.lounge" : "books.vertical" }
}
