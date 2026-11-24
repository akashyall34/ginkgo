import Foundation

/// One straight line to draw on a panel before sawing. Positions are mm from the panel's left edge (a vertical
/// line) or its bottom edge (a horizontal line), in the cutting diagram's coordinates.
public struct CutLine: Sendable, Equatable {
    public enum Direction: String, Sendable { case vertical, horizontal }

    public var direction: Direction
    /// Distance from the panel's left edge (vertical) or bottom edge (horizontal), mm.
    public var positionMm: Double
    /// Where the line starts and ends along the other axis, mm: only as long as the piece it outlines.
    public var fromMm: Double
    public var toMm: Double
    public var piece: String

    public init(direction: Direction, positionMm: Double, fromMm: Double, toMm: Double, piece: String) {
        self.direction = direction
        self.positionMm = positionMm
        self.fromMm = fromMm
        self.toMm = toMm
        self.piece = piece
    }
}

/// One piece to cut from a panel: where it sits and the lines that outline it.
public struct PieceGuide: Sendable, Equatable {
    public var name: String
    /// The piece on the panel, mm from the bottom-left corner. Width and height are its footprint on the panel.
    public var xMm: Double
    public var yMm: Double
    public var widthMm: Double
    public var heightMm: Double
    public var rotated: Bool
    public var lines: [CutLine]
    /// "Seat, 452 × 362 mm: mark 4 mm and 456 mm from the left edge, and 4 mm and 366 mm from the bottom edge."
    public var instruction: String
}

/// Every piece to mark on one original panel.
public struct PanelGuide: Sendable, Equatable {
    public var sourcePartID: String
    public var panelWidthMm: Double
    public var panelHeightMm: Double
    public var pieces: [PieceGuide]
}

/// From a proven plan to marking instructions: for each panel with cuts, every piece's outline as lines measured
/// from the panel's left and bottom edges. The pieces already sit inside the packer's margin, so sawing on the
/// outside of each line (the waste side) leaves the piece at its planned size. Pure and deterministic.
public enum CutGuide {
    public static let sawAdvice = "Saw on the outside of each line, so the blade's width comes out of the waste."

    /// One guide per panel that has cuts, in the inventory's order. A panel reused whole needs no marking.
    public static func guides(for result: ValidationResult, inventory: Inventory) -> [PanelGuide] {
        inventory.parts.compactMap { panel in
            let pieces = result.placements
                .filter { $0.sourcePartID == panel.id && !isWholePanel($0, panel) }
                .sorted { ($0.yMm, $0.xMm, $0.newPart) < ($1.yMm, $1.xMm, $1.newPart) }
                .map { piece($0) }
            guard !pieces.isEmpty else { return nil }
            return PanelGuide(sourcePartID: panel.id, panelWidthMm: panel.widthMm, panelHeightMm: panel.heightMm,
                              pieces: pieces)
        }
    }

    static func isWholePanel(_ placement: Placement, _ panel: Part) -> Bool {
        let tolerance = Packer.wholePartTolerance
        return abs(placement.widthMm - panel.widthMm) <= tolerance && abs(placement.heightMm - panel.heightMm) <= tolerance
            && placement.xMm <= tolerance && placement.yMm <= tolerance
    }

    static func piece(_ placement: Placement) -> PieceGuide {
        let left = placement.xMm, right = placement.xMm + placement.widthMm
        let bottom = placement.yMm, top = placement.yMm + placement.heightMm
        let name = placement.newPart
        let lines = [
            CutLine(direction: .vertical, positionMm: left, fromMm: bottom, toMm: top, piece: name),
            CutLine(direction: .vertical, positionMm: right, fromMm: bottom, toMm: top, piece: name),
            CutLine(direction: .horizontal, positionMm: bottom, fromMm: left, toMm: right, piece: name),
            CutLine(direction: .horizontal, positionMm: top, fromMm: left, toMm: right, piece: name),
        ]
        let size = "\(Format.mm(placement.widthMm)) × \(Format.mm(placement.heightMm)) mm"
        let instruction = "\(Format.partName(name).capitalizedFirst), \(size): "
            + "mark \(Format.mm(left)) mm and \(Format.mm(right)) mm from the left edge, "
            + "and \(Format.mm(bottom)) mm and \(Format.mm(top)) mm from the bottom edge."
        return PieceGuide(name: name, xMm: left, yMm: bottom, widthMm: placement.widthMm, heightMm: placement.heightMm,
                          rotated: placement.rotated, lines: lines, instruction: instruction)
    }
}
