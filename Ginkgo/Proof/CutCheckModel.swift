import GinkgoCore

/// After sawing: each cut piece scanned and judged against the plan, before anything is assembled.
struct CutCheckModel {
    let plan: Plan
    let inventory: Inventory
    /// The pieces that were cut (a panel reused whole needs no check), in plan order.
    let pieces: [String]
    private(set) var results: [String: CutCheckResult] = [:]
    private(set) var scanned: [String: ScannedPiece] = [:]

    init(plan: Plan, result: ValidationResult, inventory: Inventory) {
        self.plan = plan
        self.inventory = inventory
        let cut = Set(CutGuide.guides(for: result, inventory: inventory).flatMap(\.pieces).map(\.name))
        pieces = plan.newParts.map(\.name).filter { cut.contains($0) }
    }

    /// Records a piece's scan (meters, as the Scan screen measures) and judges it.
    mutating func record(piece: String, widthMeters: Float, heightMeters: Float) {
        guard pieces.contains(piece), widthMeters > 0, heightMeters > 0 else { return }
        let scan = ScannedPiece(name: piece, widthMm: (Double(widthMeters) * 10_000).rounded() / 10,
                                heightMm: (Double(heightMeters) * 10_000).rounded() / 10)
        scanned[piece] = scan
        results[piece] = CutCheck.check(scan, plan: plan, inventory: inventory)
    }

    /// Supports that must be trimmed to match each other.
    var supportWarnings: [String] { CutCheck.matchSupports(Array(scanned.values), plan: plan) }

    var remaining: Int { pieces.filter { results[$0] == nil }.count }

    /// Every piece scanned and usable, and the supports match.
    var readyToAssemble: Bool {
        remaining == 0 && supportWarnings.isEmpty && results.values.allSatisfy {
            switch $0.verdict {
            case .good, .useAsIs: return true
            case .trim, .recut: return false
            }
        }
    }

    var summary: String {
        if pieces.isEmpty { return "Nothing was cut, so there's nothing to check." }
        if remaining > 0 { return "Scan each piece after cutting: \(remaining) of \(pieces.count) to go." }
        return readyToAssemble ? "Every piece checks out. Ready to assemble."
                               : "Fix the pieces marked below, then scan them again."
    }
}
