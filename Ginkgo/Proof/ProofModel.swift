import GinkgoCore
import Foundation

/// Everything the Proof screen shows, worked out from a plan, its validation result
/// and the confirmed parts. Pure data, so every rule here is unit tested.
struct ProofModel {
    let plan: Plan
    let result: ValidationResult
    let inventory: Inventory

    enum Verdict: Equatable {
        case proven
        case fails(problems: Int)
    }

    struct CutRow: Equatable {
        let name: String
        /// "40.0 × 30.0 cm"
        let size: String
        /// "From the top"
        let source: String
        /// Plain-English problems with this piece; empty when it fits.
        let problems: [String]
        var fits: Bool { problems.isEmpty }
    }

    struct SagRow: Equatable {
        let name: String
        let deflectionMm: Double
        let limitMm: Double
        let passes: Bool
        /// How much of the allowed sag is used: 0.7 means 70%. Above 1 fails.
        var shareOfLimit: Double { limitMm > 0 ? deflectionMm / limitMm : .infinity }
        /// "0.42 of 0.60 mm allowed"
        var summary: String { String(format: "%.2f of %.2f mm allowed", deflectionMm, limitMm) }
    }

    /// One original panel with the pieces cut from it, for the cutting diagram.
    struct Sheet {
        let part: Part
        let name: String
        let cuts: [Placement]
    }

    var verdict: Verdict {
        result.passes && result.violations.isEmpty ? .proven : .fails(problems: result.violations.count)
    }

    var headline: String {
        switch verdict {
        case .proven: return "Proven to fit"
        case .fails(let n): return n == 1 ? "Doesn't fit: 1 problem" : "Doesn't fit: \(n) problems"
        }
    }

    var cuts: [CutRow] {
        plan.newParts.map { piece in
            CutRow(name: Self.displayName(piece.name),
                   size: String(format: "%.1f × %.1f cm", piece.widthMm / 10, piece.heightMm / 10),
                   source: "From the " + Self.displayName(piece.sourcePartID).lowercased(),
                   problems: result.violations.filter { $0.newPart == piece.name }.map(\.message))
        }
    }

    /// Problems not tied to any planned piece (for example, the build is too tall overall).
    var otherProblems: [String] {
        let pieces = Set(plan.newParts.map(\.name))
        return result.violations.filter { !pieces.contains($0.newPart) }.map(\.message)
    }

    var sagRows: [SagRow] {
        result.sag.map {
            SagRow(name: Self.displayName($0.newPart), deflectionMm: $0.deflectionMm, limitMm: $0.limitMm, passes: $0.passes)
        }
    }

    /// Panels in inventory order, each with its cuts; panels with no cuts are left out.
    var sheets: [Sheet] {
        inventory.parts.compactMap { part in
            let cuts = result.placements.filter { $0.sourcePartID == part.id }
            return cuts.isEmpty ? nil : Sheet(part: part, name: Self.displayName(part.id), cuts: cuts)
        }
    }

    /// The measurements with the least room to spare, tightest first.
    var checksBeforeCutting: [String] {
        result.verify.sorted { $0.marginMm < $1.marginMm }.map {
            let side = String(format: "Check the %@'s %@", Self.displayName($0.sourcePartID).lowercased(), $0.dimension.rawValue)
            // Spare is what's left after the saw cut and measuring allowance (Packer.margin).
            if $0.marginMm < 0.5 {
                return side + String(format: ": a tight fit, with only the %.0f mm cutting allowance to spare.", Packer.margin)
            }
            return side + String(format: ": %.0f mm to spare.", $0.marginMm)
        }
    }

    var reuse: String { String(format: "%.0f%% of the wood reused", result.reusePercent) }

    /// "side_left" → "Left side", "drawer_front" → "Drawer front", "leg_right" → "Right leg".
    static func displayName(_ id: String) -> String {
        var words = id.split(separator: "_").map(String.init)
        if let last = words.last, ["left", "right"].contains(last), words.count > 1 {
            words.insert(words.removeLast(), at: 0)
        }
        let text = words.joined(separator: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

extension ProofModel {
    /// The bundled example: a nightstand turned into a bench, as validated by Ginkgo,
    /// or the chatbot's plan for the same nightstand with its problems.
    static func example(chatbot: Bool = false, bundle: Bundle = .main) -> ProofModel? {
        func load<T: Decodable>(_ name: String, as: T.Type) -> T? {
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        guard let inventory = load("inventory", as: Inventory.self) else { return nil }
        if chatbot {
            guard let plan = load("plan_chatbot", as: Plan.self) else { return nil }
            return ProofModel(plan: plan, result: Validator.validate(plan: plan, inventory: inventory, limits: nil),
                              inventory: inventory)
        }
        // Ginkgo's own plan for the nightstand: the rule-based bench, laid out in 3D and validated.
        return try? LivePlan.proof(from: inventory).get()
    }
}
