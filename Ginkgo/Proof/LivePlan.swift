import Foundation
import GinkgoCore

/// From a real measurement to a proven plan, with no internet: the measured box becomes a parts
/// list, the rule-based planner proposes a bench, and the validator proves it.
/// When the Parts step (Gemini reading the photo) is in, its confirmed parts list replaces `inventory(from:)`.
enum LivePlan {
    /// Typical panel thickness for furniture like this, until the Parts step confirms the real one.
    static let assumedThicknessMm = 18.0

    enum Failure: Error, Equatable {
        /// The piece is too small, or shaped so, that no bench passes the validator.
        case noBenchFits

        var explanation: String {
            "No bench fits these panels. A bigger piece of furniture, or a different build, is needed."
        }
    }

    /// A panel piece seen as a box: the top (length × width) on two sides (width × height).
    static func inventory(from box: FittedBox, scanID: String) -> Inventory {
        let length = (Double(box.length) * 1000).rounded(), width = (Double(box.width) * 1000).rounded()
        let height = (Double(box.height) * 1000).rounded()
        let t = assumedThicknessMm
        func panel(_ id: String, _ type: TypeEnum, _ w: Double, _ h: Double) -> Part {
            Part(damaged: false, heightMm: h, id: id, keepOuts: [], material: .solidWood, thicknessMm: t, type: type, widthMm: w)
        }
        return Inventory(parts: [
            panel("top", .top, length, width),
            panel("side_left", .side, width, height - t),
            panel("side_right", .side, width, height - t),
        ], scanID: scanID)
    }

    static func proof(from inventory: Inventory) -> Result<ProofModel, Failure> {
        guard let bench = RuleBasedPlanner.bench(inventory: inventory) else { return .failure(.noBenchFits) }
        return .success(ProofModel(plan: bench.plan, result: bench.validation, inventory: inventory))
    }

    static func proof(from box: FittedBox, scanID: String) -> Result<ProofModel, Failure> {
        proof(from: inventory(from: box, scanID: scanID))
    }
}
