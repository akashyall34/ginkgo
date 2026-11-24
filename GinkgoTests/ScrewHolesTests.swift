import CoreGraphics
import GinkgoCore
import XCTest
@testable import Ginkgo

final class ScrewHolesTests: XCTestCase {
    // A hole in the middle leaves room for the seat only turned sideways, so the grain runs that way (top to bottom):
    // this test is about cutting around holes; the grain rule has its own tests.
    private let top = Part(damaged: false, grain: .alongHeight, heightMm: 400, id: "top", keepOuts: [], material: .solidWood,
                           materialSource: .confirmed, thicknessMm: 18, thicknessSource: .tape, type: .top, widthMm: 600)

    func testATapBecomesAKeepOutCenteredOnIt() {
        // Tap 25% across and 25% down: 150 mm from the left, 300 mm up from the bottom.
        let hole = ScrewHoles.keepOut(at: CGPoint(x: 0.25, y: 0.25), on: top)
        XCTAssertEqual(hole, Rect(heightMm: 20, widthMm: 20, xMm: 140, yMm: 290))
        let back = ScrewHoles.point(of: hole, on: top)
        XCTAssertEqual(back.x, 0.25, accuracy: 1e-9)
        XCTAssertEqual(back.y, 0.25, accuracy: 1e-9)
    }

    func testAHoleAtTheEdgeStaysInsideThePanel() {
        let corner = ScrewHoles.keepOut(at: CGPoint(x: 0, y: 1), on: top)
        XCTAssertEqual(corner.xMm, 0)
        XCTAssertEqual(corner.yMm, 0)
        let far = ScrewHoles.keepOut(at: CGPoint(x: 1.2, y: -0.1), on: top)
        XCTAssertEqual(far.xMm + far.widthMm, 600)
        XCTAssertEqual(far.yMm + far.heightMm, 400)
    }

    func testTappingAgainRemovesTheHole() {
        let one = ScrewHoles.toggling(at: CGPoint(x: 0.5, y: 0.5), on: top)
        XCTAssertEqual(one.keepOuts.count, 1)
        let two = ScrewHoles.toggling(at: CGPoint(x: 0.1, y: 0.1), on: one)
        XCTAssertEqual(two.keepOuts.count, 2)
        XCTAssertEqual(ScrewHoles.toggling(at: CGPoint(x: 0.505, y: 0.5), on: two).keepOuts.count, 1, "Near an existing hole removes it")
    }

    func testTheValidatorCutsAroundAMarkedHole() throws {
        // A hole marked in the middle of the top: the plan still passes, and the seat is cut clear of it.
        let side = Part(damaged: false, grain: .alongHeight, heightMm: 560, id: "side_left", keepOuts: [],
                        material: .solidWood, materialSource: .confirmed, thicknessMm: 18, thicknessSource: .tape,
                        type: .side, widthMm: 400)
        let holedTop = ScrewHoles.toggling(at: CGPoint(x: 0.5, y: 0.5), on: top)
        let hole = try XCTUnwrap(holedTop.keepOuts.first)
        let inventory = Inventory(parts: [holedTop, side, side.with(id: "side_right")], scanID: "s")
        let model = try LivePlan.proof(from: inventory).get()
        let cuts = model.result.placements.filter { $0.sourcePartID == "top" }
        XCTAssertFalse(cuts.isEmpty)
        for cut in cuts {
            let apart = cut.xMm + cut.widthMm <= hole.xMm || hole.xMm + hole.widthMm <= cut.xMm
                || cut.yMm + cut.heightMm <= hole.yMm || hole.yMm + hole.heightMm <= cut.yMm
            XCTAssertTrue(apart, "\(cut.newPart) overlaps the screw hole")
        }
    }
}
