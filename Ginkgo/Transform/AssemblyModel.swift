import GinkgoCore

/// Step-by-step assembly: one tested step at a time, and which pieces are in place by then, for the 3D view.
struct AssemblyModel {
    let guide: AssemblyGuide.Guide
    let scene: TransformScene
    private(set) var index = 0

    init(plan: Plan, inventory: Inventory) {
        guide = AssemblyGuide.guide(for: plan, inventory: inventory)
        scene = TransformLayout.scene(plan: plan, inventory: inventory)
    }

    var steps: [AssemblyStep] { guide.steps }
    var current: AssemblyStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index >= steps.count - 1 }

    /// "Step 2 of 7".
    var title: String { steps.isEmpty ? "Nothing to assemble" : "Step \(index + 1) of \(steps.count)" }

    /// The pieces placed by this step, at their finished positions, and whether each is new at this step.
    var visible: [(piece: TransformPiece, isNew: Bool)] {
        guard let current else { return [] }
        let before = Set(index > 0 ? steps[index - 1].placed : [])
        return scene.pieces.filter { current.placed.contains($0.name) }.map { ($0, !before.contains($0.name)) }
    }

    /// When nothing is in place yet (sanding, laying out), the finished build, so the view is never empty.
    var preview: [TransformPiece] { visible.isEmpty ? scene.pieces : [] }

    mutating func next() { if !isLast { index += 1 } }
    mutating func previous() { if !isFirst { index -= 1 } }
}
