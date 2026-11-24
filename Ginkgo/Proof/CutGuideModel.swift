import GinkgoCore

/// Steps through the panels that have cuts, one at a time: the drawing, each piece's marks, then the saw advice.
struct CutGuideModel {
    let panels: [PanelGuide]
    let inventory: Inventory
    let placements: [Placement]
    private(set) var index = 0

    init(result: ValidationResult, inventory: Inventory) {
        panels = CutGuide.guides(for: result, inventory: inventory)
        self.inventory = inventory
        placements = result.placements
    }

    var isEmpty: Bool { panels.isEmpty }
    var current: PanelGuide? { panels.indices.contains(index) ? panels[index] : nil }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index >= panels.count - 1 }

    /// "Panel 1 of 3: Top".
    var title: String {
        guard let current else { return "No cuts to mark" }
        return "Panel \(index + 1) of \(panels.count): \(ProofModel.displayName(current.sourcePartID))"
    }

    /// The marks for the current panel, then the saw advice.
    var steps: [String] {
        guard let current else { return [] }
        return current.pieces.map(\.instruction) + [CutGuide.sawAdvice]
    }

    /// The current panel drawn to scale with its pieces, for the cutting diagram.
    var sheet: ProofModel.Sheet? {
        guard let current, let part = inventory.parts.first(where: { $0.id == current.sourcePartID }) else { return nil }
        return ProofModel.Sheet(part: part, name: ProofModel.displayName(part.id),
                                cuts: placements.filter { $0.sourcePartID == part.id })
    }

    mutating func next() { if !isLast { index += 1 } }
    mutating func previous() { if !isFirst { index -= 1 } }
}
