import GinkgoCore
import simd

/// The AR marking flow for one panel: the person taps three corners, Ginkgo checks them against the scanned size,
/// then the cut lines can be drawn on the real panel. Wrong taps are explained and the taps start over.
struct CutMarkingModel {
    let panel: PanelGuide
    private(set) var taps: [SIMD3<Float>] = []
    private(set) var frame: PanelFrame?
    private(set) var problem: String?

    static let corners = ["bottom-left", "bottom-right", "top-left"]

    init(panel: PanelGuide) { self.panel = panel }

    /// What to do now.
    var prompt: String {
        if frame != nil { return "Mark along each green line with a pencil. Saw on the outside of the line." }
        let next = Self.corners[min(taps.count, Self.corners.count - 1)]
        return "Tap the panel's \(next) corner, as in the drawing."
    }

    mutating func tap(_ point: SIMD3<Float>) {
        guard frame == nil else { return }
        problem = nil
        taps.append(point)
        guard taps.count == Self.corners.count else { return }
        switch PanelFrame.from(bottomLeft: taps[0], bottomRight: taps[1], topLeft: taps[2],
                               expectedWidthMm: panel.panelWidthMm, expectedHeightMm: panel.panelHeightMm) {
        case .success(let placed): frame = placed
        case .failure(let error):
            problem = error.explanation
            taps = []
        }
    }

    mutating func reset() {
        taps = []
        frame = nil
        problem = nil
    }

    /// Every cut line's ends on the real panel, once the corners are placed.
    var lines: [(SIMD3<Float>, SIMD3<Float>)] {
        guard let frame else { return [] }
        return panel.pieces.flatMap(\.lines).map { frame.ends(of: CutLineEnds($0)) }
    }
}
