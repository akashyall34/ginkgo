@testable import GinkgoCore
import XCTest

final class PackerTests: XCTestCase {
    private func panel(_ width: Double, _ height: Double, keepOuts: [Rect] = [], id: String = "panel") -> Part {
        Part(damaged: false, heightMm: height, id: id, keepOuts: keepOuts, material: .solidWood,
             thicknessMm: 19, type: .side, widthMm: width)
    }

    private func example(_ id: String) throws -> Part {
        try XCTUnwrap(try Fixtures.inventory().parts.first { $0.id == id })
    }

    private func cut(_ name: String, _ width: Double, _ height: Double) -> CutRequest {
        CutRequest(name: name, widthMm: width, heightMm: height)
    }

    /// A placement from `frame` = [x, y, width, height] in mm.
    private func place(_ name: String, _ frame: [Double], rotated: Bool = false, source: String) -> Placement {
        Placement(heightMm: frame[3], newPart: name, rotated: rotated, sourcePartID: source,
                  widthMm: frame[2], xMm: frame[0], yMm: frame[1])
    }

    // MARK: - Known answers from the guide

    func testExactFitLeavesNoSpare() {
        let result = Packer.pack(source: panel(460, 400), cuts: [cut("seat", 452, 392)])
        XCTAssertEqual(result.placements, [place("seat", [4, 4, 452, 392], source: "panel")])
        XCTAssertEqual(result.failures, [])
        XCTAssertEqual(result.spareWidthMm, 0)
        XCTAssertEqual(result.spareHeightMm, 0)
    }

    func testOneMillimetreTooWideFails() throws {
        let result = Packer.pack(source: panel(460, 400), cuts: [cut("seat", 453, 392)])
        XCTAssertEqual(result.placements, [])
        let failure = try XCTUnwrap(result.failures.first)
        XCTAssertEqual(failure.reason, .tooBig)
        XCTAssertEqual(failure.shortByMm, 1)
        XCTAssertEqual(failure.neededMm, [461, 400])
        XCTAssertEqual(failure.availableMm, [460, 400])
        XCTAssertNil(failure.maxHeightMm, "no height makes a 453 mm wide cut fit a 460 mm panel")
        XCTAssertEqual(failure.maxWidthMm, 443)
        XCTAssertEqual(failure.hint, "Fits with width 443 mm or less at height 392 mm.")
        XCTAssertEqual(result.spareWidthMm, 460, "nothing placed, so the whole panel is spare")
        XCTAssertEqual(result.spareHeightMm, 400)
    }

    func testFitsRotatedWhenOnlyTheTurnedCutFits() {
        let result = Packer.pack(source: panel(400, 460), cuts: [cut("seat", 452, 392)])
        XCTAssertEqual(result.placements, [
            place("seat", [4, 4, 392, 452], rotated: true, source: "panel"),
        ])
        XCTAssertEqual(result.spareWidthMm, 0)
        XCTAssertEqual(result.spareHeightMm, 0)
    }

    func testSeatMayTouchTheKeepOutEdge() throws {
        let result = Packer.pack(source: try example("top"), cuts: [cut("seat", 400, 300)])
        XCTAssertEqual(result.placements, [place("seat", [4, 34, 400, 300], source: "top")])
        XCTAssertEqual(result.spareWidthMm, 52)
        XCTAssertEqual(result.spareHeightMm, 62)
    }

    func testKeepOutsBlockAFullSizeCutAndTheHintSaysWhatFits() throws {
        let result = Packer.pack(source: try example("top"), cuts: [cut("seat", 452, 392)])
        let failure = try XCTUnwrap(result.failures.first)
        XCTAssertEqual(failure.reason, .blockedByKeepOuts)
        XCTAssertEqual(failure.shortByMm, 0, "the cut fits a clear panel exactly")
        XCTAssertEqual(failure.maxHeightMm, 362)
        XCTAssertEqual(failure.maxWidthMm, 392)
        XCTAssertEqual(failure.hint,
                       "Fits with height 362 mm or less at width 452 mm, or width 392 mm or less at height 392 mm.")
    }

    func testTwoCutsFromOneSideDoNotOverlap() throws {
        let result = Packer.pack(source: try example("side_left"), cuts: [cut("leg", 300, 380), cut("brace", 60, 100)])
        XCTAssertEqual(result.placements, [
            place("leg", [4, 4, 300, 380], source: "side_left"),
            place("brace", [312, 4, 60, 100], source: "side_left"),
        ], "the brace's box starts exactly where the leg's box ends: touching is allowed")
        XCTAssertEqual(result.failures, [])
        XCTAssertEqual(result.spareWidthMm, 4)
        XCTAssertEqual(result.spareHeightMm, 172)
    }

    func testWholePartIsReusedWithoutMargin() throws {
        let result = Packer.pack(source: try example("side_left"), cuts: [cut("side", 380, 560)])
        XCTAssertEqual(result.placements, [place("side", [0, 0, 380, 560], source: "side_left")])
        XCTAssertEqual(result.spareWidthMm, 0)
        XCTAssertEqual(result.spareHeightMm, 0)
    }

    func testSecondWholePartFromOnePanelDoesNotFit() throws {
        let result = Packer.pack(source: try example("side_left"), cuts: [cut("a", 380, 560), cut("b", 380, 560)])
        XCTAssertEqual(result.placements.map(\.newPart), ["a"])
        let failure = try XCTUnwrap(result.failures.first)
        XCTAssertEqual(failure.name, "b")
        XCTAssertEqual(failure.reason, .noRoomLeft)
        XCTAssertEqual(failure.shortByMm, 0)
        XCTAssertEqual(failure.neededMm, [380, 560])
        XCTAssertNil(failure.maxHeightMm)
        XCTAssertEqual(failure.hint, "This part is reused whole, and another cut already uses it.")
    }

    func testZeroNegativeAndNonNumberSizesAreRejectedWithoutCrashing() {
        let cuts = [cut("zero", 0, 100), cut("negative", -5, 100), cut("nan", .nan, 100), cut("ok", 100, 100)]
        let result = Packer.pack(source: panel(460, 400), cuts: cuts)
        XCTAssertEqual(result.failures.map(\.name), ["zero", "negative", "nan"])
        XCTAssertEqual(Set(result.failures.map(\.reason)), [.invalidSize])
        XCTAssertEqual(result.failures.first?.hint, "Width and height must be more than 0 mm.")
        XCTAssertEqual(result.placements.map(\.newPart), ["ok"], "valid cuts are still placed")
    }

    // MARK: - Boundaries and other paths

    func testWholePartWithinOneMillimetreAndTurned() throws {
        let side = try example("side_left")
        let turned = Packer.pack(source: side, cuts: [cut("side", 559, 381)])
        XCTAssertEqual(turned.placements, [
            place("side", [0, 0, 380, 560], rotated: true, source: "side_left"),
        ])
        let notWhole = Packer.pack(source: side, cuts: [cut("side", 382, 560)])
        XCTAssertEqual(notWhole.failures.first?.reason, .tooBig, "2 mm off is a real cut and needs the margin")
    }

    func testWholePartIgnoresKeepOuts() throws {
        let result = Packer.pack(source: try example("top"), cuts: [cut("top", 460, 400)])
        XCTAssertEqual(result.placements, [place("top", [0, 0, 460, 400], source: "top")])
    }

    func testNoRoomLeftForASecondFullCut() throws {
        let result = Packer.pack(source: try example("side_left"), cuts: [cut("a", 300, 380), cut("b", 300, 380)])
        let failure = try XCTUnwrap(result.failures.first)
        XCTAssertEqual(failure.name, "b")
        XCTAssertEqual(failure.reason, .noRoomLeft)
        XCTAssertEqual(failure.shortByMm, 0)
        XCTAssertEqual(failure.maxHeightMm, 160, "box 308 × 168 fits above the first cut's box (172 mm left)")
        XCTAssertEqual(failure.maxWidthMm, 60, "box 68 × 388 fits beside the first cut's box (72 mm left)")
    }

    func testNothingSmallerFits() throws {
        let result = Packer.pack(source: panel(20, 20), cuts: [cut("big", 50, 50)])
        let failure = try XCTUnwrap(result.failures.first)
        XCTAssertEqual(failure.shortByMm, 38)
        XCTAssertNil(failure.maxHeightMm)
        XCTAssertNil(failure.maxWidthMm)
        XCTAssertEqual(failure.hint, "No smaller size with the same width or height fits.")
    }

    func testShortByUsesTheBetterOrientation() throws {
        let result = Packer.pack(source: panel(400, 460), cuts: [cut("seat", 455, 300)])
        XCTAssertEqual(result.failures.first?.shortByMm, 3, "turned, 463 mm is needed on a 460 mm side")
    }

    func testLargestCutIsPlacedFirstWhateverTheInputOrder() {
        let cuts = [cut("small", 50, 50), cut("large", 300, 300)]
        let result = Packer.pack(source: panel(460, 400), cuts: cuts)
        XCTAssertEqual(result.placements.map(\.newPart), ["large", "small"])
        XCTAssertEqual(result.placements.first?.xMm, 4)
    }

    func testEqualAreasGoByNameThenInputOrder() {
        let byName = Packer.pack(source: panel(460, 400), cuts: [cut("b", 100, 50), cut("a", 50, 100)])
        XCTAssertEqual(byName.placements.map(\.newPart), ["a", "b"])
        let sameName = Packer.pack(source: panel(460, 400), cuts: [cut("x", 100, 50), cut("x", 50, 100)])
        XCTAssertEqual(sameName.placements.map(\.widthMm), [100, 50], "same area and name keep the input order")
    }

    func testPackingIsDeterministic() throws {
        let cuts = [cut("a", 120, 80), cut("b", 80, 120), cut("c", 200, 30), cut("d", 30, 200), cut("e", 60, 60)]
        let first = Packer.pack(source: try example("top"), cuts: cuts)
        XCTAssertEqual(first, Packer.pack(source: try example("top"), cuts: cuts))
        XCTAssertEqual(first, Packer.pack(source: try example("top"), cuts: cuts.reversed()))
    }

    func testNoPlacedBoxesOverlapOrLeaveThePanel() throws {
        let top = try example("top")
        var cuts: [CutRequest] = []
        for index in 1...12 {
            let step = Double(index)
            cuts.append(cut("p\(index)", 40 + step * 7, 30 + step * 5))
        }
        let result = Packer.pack(source: top, cuts: cuts)
        let boxes: [Box] = result.placements.map { placement in
            Box(x: placement.xMm - 4, y: placement.yMm - 4, width: placement.widthMm + 8, height: placement.heightMm + 8)
        }
        let keepOuts = top.keepOuts.map(Box.init)
        for (index, box) in boxes.enumerated() {
            XCTAssertTrue(box.fits(width: top.widthMm, height: top.heightMm))
            XCTAssertFalse(keepOuts.contains(where: box.overlaps))
            XCTAssertFalse(boxes[(index + 1)...].contains(where: box.overlaps))
        }
        XCTAssertEqual(result.placements.count + result.failures.count, cuts.count)
    }

    func testBoxOverlapIsStrict() {
        let box = Box(x: 0, y: 0, width: 10, height: 10)
        XCTAssertFalse(box.overlaps(Box(x: 10, y: 0, width: 5, height: 5)), "touching on the right")
        XCTAssertFalse(box.overlaps(Box(x: 0, y: 10, width: 5, height: 5)), "touching on top")
        XCTAssertTrue(box.overlaps(Box(x: 9.5, y: 9.5, width: 5, height: 5)))
        XCTAssertTrue(box.fits(width: 10, height: 10))
        XCTAssertFalse(box.fits(width: 9.9, height: 10))
    }

    func testFormatMillimetres() {
        XCTAssertEqual(Format.mm(52), "52")
        XCTAssertEqual(Format.mm(0.4), "0.4")
        XCTAssertEqual(Format.mm(361.96), "362")
        XCTAssertEqual(Format.mm(-0.01), "0")
        XCTAssertEqual(Format.mm(2.933), "2.9")
    }
}
