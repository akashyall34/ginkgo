@testable import GinkgoCore
import XCTest

/// Marking instructions from a proven plan: the right lines, at the right distances, never through a screw hole.
final class CutGuideTests: XCTestCase {
    private func benchGuides() throws -> (guides: [PanelGuide], inventory: Inventory) {
        let inventory = try Fixtures.inventory()
        let result = Validator.validate(plan: try Fixtures.planBench(), inventory: inventory, limits: nil)
        XCTAssertTrue(result.passes, "\(result.violations)")
        return (CutGuide.guides(for: result, inventory: inventory), inventory)
    }

    /// `rect` is x, y, width, height in mm from the panel's bottom-left corner.
    private func placement(_ name: String, on source: String, _ rect: [Double], rotated: Bool = false) -> Placement {
        Placement(heightMm: rect[3], newPart: name, rotated: rotated, sourcePartID: source, widthMm: rect[2],
                  xMm: rect[0], yMm: rect[1])
    }

    private func result(_ placements: [Placement]) -> ValidationResult {
        ValidationResult(passes: true, placements: placements, planID: "p", reusePercent: 50, sag: [], verify: [],
                         violations: [])
    }

    // MARK: - Known answer: the sample bench

    func testTheSeatIsMarkedAboveTheScrewHolesAtKnownDistances() throws {
        // Top 460 × 400 mm with screw holes at y 20-30 mm: the seat's 408 × 308 reserved box can't start at the corner,
        // so it starts at y = 30; with the 4 mm inset the seat sits at (4, 34).
        let top = try XCTUnwrap(try benchGuides().guides.first { $0.sourcePartID == "top" })
        let seat = try XCTUnwrap(top.pieces.first { $0.name == "seat" })
        XCTAssertEqual([seat.xMm, seat.yMm, seat.widthMm, seat.heightMm], [4, 34, 400, 300])
        XCTAssertEqual(seat.instruction,
                       "Seat, 400 × 300 mm: mark 4 mm and 404 mm from the left edge, and 34 mm and 334 mm from the bottom edge.")
    }

    func testEachPieceIsOutlinedByFourLines() throws {
        for panel in try benchGuides().guides {
            for piece in panel.pieces {
                XCTAssertEqual(piece.lines.filter { $0.direction == .vertical }.map(\.positionMm),
                               [piece.xMm, piece.xMm + piece.widthMm])
                XCTAssertEqual(piece.lines.filter { $0.direction == .horizontal }.map(\.positionMm),
                               [piece.yMm, piece.yMm + piece.heightMm])
                XCTAssertTrue(piece.lines.allSatisfy { $0.piece == piece.name })
            }
        }
    }

    func testEveryLineStaysOnItsPanel() throws {
        for panel in try benchGuides().guides {
            for line in panel.pieces.flatMap(\.lines) {
                let (across, along) = line.direction == .vertical
                    ? (panel.panelWidthMm, panel.panelHeightMm) : (panel.panelHeightMm, panel.panelWidthMm)
                XCTAssertTrue((0...across).contains(line.positionMm), "\(line)")
                XCTAssertTrue(line.fromMm >= 0 && line.toMm <= along && line.fromMm < line.toMm, "\(line)")
            }
        }
    }

    func testNoPieceCoversAScrewHole() throws {
        let (guides, inventory) = try benchGuides()
        for panel in guides {
            let holes = try XCTUnwrap(inventory.parts.first { $0.id == panel.sourcePartID }).keepOuts
            for piece in panel.pieces {
                for hole in holes {
                    let overlaps = piece.xMm < hole.xMm + hole.widthMm && hole.xMm < piece.xMm + piece.widthMm
                        && piece.yMm < hole.yMm + hole.heightMm && hole.yMm < piece.yMm + piece.heightMm
                    XCTAssertFalse(overlaps, "\(piece.name) covers a screw hole on \(panel.sourcePartID)")
                }
            }
        }
    }

    // MARK: - Which panels get a guide

    func testAPanelReusedWholeNeedsNoMarking() throws {
        let panel = try XCTUnwrap(try Fixtures.inventory().parts.first)
        let whole = placement("table_top", on: panel.id, [0, 0, panel.widthMm, panel.heightMm])
        let inventory = Inventory(parts: [panel], scanID: "s")
        XCTAssertEqual(CutGuide.guides(for: result([whole]), inventory: inventory), [])
    }

    func testOnlyPanelsWithCutsGetAGuideInInventoryOrder() throws {
        let inventory = try Fixtures.inventory()
        let cuts = [placement("b", on: "side_right", [4, 4, 100, 100]),
                    placement("a", on: "top", [4, 34, 100, 100])]
        XCTAssertEqual(CutGuide.guides(for: result(cuts), inventory: inventory).map(\.sourcePartID), ["top", "side_right"])
    }

    func testPiecesOnAPanelGoBottomToTopThenLeftToRight() throws {
        let inventory = try Fixtures.inventory()
        let cuts = [placement("upper", on: "top", [4, 200, 100, 100]),
                    placement("right", on: "top", [200, 4, 100, 100]),
                    placement("left", on: "top", [4, 4, 100, 100])]
        let guide = try XCTUnwrap(CutGuide.guides(for: result(cuts), inventory: inventory).first)
        XCTAssertEqual(guide.pieces.map(\.name), ["left", "right", "upper"])
    }

    func testARotatedPieceKeepsItsFootprintAndSaysSo() throws {
        let inventory = try Fixtures.inventory()
        let cut = placement("rail", on: "top", [4, 4, 60, 380], rotated: true)
        let piece = try XCTUnwrap(CutGuide.guides(for: result([cut]), inventory: inventory).first?.pieces.first)
        XCTAssertTrue(piece.rotated)
        XCTAssertEqual(piece.instruction,
                       "Rail, 60 × 380 mm: mark 4 mm and 64 mm from the left edge, and 4 mm and 384 mm from the bottom edge.")
    }

    func testHalfMillimetresAreKept() throws {
        let inventory = try Fixtures.inventory()
        let cut = placement("strip", on: "top", [4.5, 4, 100.25, 50])
        let piece = try XCTUnwrap(CutGuide.guides(for: result([cut]), inventory: inventory).first?.pieces.first)
        XCTAssertTrue(piece.instruction.contains("mark 4.5 mm and 104.8 mm from the left edge"), piece.instruction)
    }

    func testTheSawAdviceKeepsThePieceAtSize() {
        XCTAssertTrue(CutGuide.sawAdvice.contains("outside of each line"))
    }
}
