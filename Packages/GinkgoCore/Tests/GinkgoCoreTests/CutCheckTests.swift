@testable import GinkgoCore
import XCTest

/// Cut pieces against the sample bench (seat 400 × 300, supports 300 × 380): good, trim, use as is, or recut.
final class CutCheckTests: XCTestCase {
    private func check(_ name: String, _ width: Double, _ height: Double) throws -> CutCheckResult {
        CutCheck.check(ScannedPiece(name: name, widthMm: width, heightMm: height), plan: try Fixtures.planBench(),
                       inventory: try Fixtures.inventory())
    }

    // MARK: - Good

    func testAPieceWithinTwoMillimetresIsGood() throws {
        let result = try check("seat", 401, 299.5)
        XCTAssertEqual(result.verdict, .good)
        XCTAssertEqual(result.message, "Seat: 401 × 299.5 mm, within 2 mm. Good.")
    }

    func testAPieceScannedTheOtherWayRoundIsStillGood() throws {
        XCTAssertEqual(try check("seat", 300, 400).verdict, .good)
    }

    func testExactlyTwoMillimetresOverIsStillGood() throws {
        XCTAssertEqual(try check("seat", 402, 300).verdict, .good)
        XCTAssertEqual(try check("seat", 398, 300).verdict, .good)
    }

    // MARK: - Trim

    func testJustPastTheToleranceMustBeTrimmed() throws {
        XCTAssertEqual(try check("seat", 402.5, 300).verdict, .trim(widthMm: 2.5, heightMm: 0))
    }

    func testATooLongPieceGetsItsTrimInWords() throws {
        let result = try check("seat", 407, 300)
        XCTAssertEqual(result.verdict, .trim(widthMm: 7, heightMm: 0))
        XCTAssertEqual(result.message, "Seat: too long. Trim 7 mm off its width, then scan it again.")
    }

    func testTooLongBothWaysTrimsBoth() throws {
        XCTAssertEqual(try check("seat", 405, 304).message,
                       "Seat: too long. Trim 5 mm off its width and 4 mm off its height, then scan it again.")
    }

    func testATrimIsNamedByThePiecesOwnWidthAndHeight() throws {
        // The supports are 300 wide and 380 high: 6 mm too much on the long side is height, not width.
        XCTAssertEqual(try check("leg_left", 300, 386).verdict, .trim(widthMm: 0, heightMm: 6))
    }

    // MARK: - Short: the validator decides

    func testASlightlyNarrowSupportIsStillProvenSoUseItAsIs() throws {
        let result = try check("leg_left", 296, 380)
        XCTAssertEqual(result.verdict, .useAsIs(shortByMm: 4))
        XCTAssertTrue(result.message.contains("still passes every check"), result.message)
    }

    func testASupportCutTooNarrowToStandMustBeRecut() throws {
        // Narrower than the 150 mm a support needs not to tip.
        let result = try check("leg_left", 140, 380)
        guard case .recut(let reason) = result.verdict else { return XCTFail("\(result.verdict)") }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertTrue(result.message.contains("Cut it again"), result.message)
    }

    func testAPieceNotInThePlanIsFlagged() throws {
        let result = try check("shelf", 400, 300)
        XCTAssertEqual(result.verdict, .recut(reason: "shelf isn't in this plan."))
    }

    // MARK: - Matching supports

    private func supports(_ left: Double, _ right: Double?) -> [ScannedPiece] {
        [ScannedPiece(name: "leg_left", widthMm: 300, heightMm: left)]
            + (right.map { [ScannedPiece(name: "leg_right", widthMm: 300, heightMm: $0)] } ?? [])
    }

    func testSupportsThatDifferTooMuchGetTheTallerTrimmed() throws {
        XCTAssertEqual(CutCheck.matchSupports(supports(380, 385), plan: try Fixtures.planBench()),
                       ["Right leg: trim 5 mm off its long side to match the other supports, or the build will wobble."])
    }

    func testSupportsWithinTheToleranceMatch() throws {
        XCTAssertEqual(CutCheck.matchSupports(supports(380, 382), plan: try Fixtures.planBench()), [])
    }

    func testOneSupportAloneHasNothingToMatch() throws {
        XCTAssertEqual(CutCheck.matchSupports(supports(380, nil), plan: try Fixtures.planBench()), [])
    }

    func testTheToleranceIsTwoMillimetres() {
        XCTAssertEqual(CutCheck.toleranceMm, 2)
    }
}
