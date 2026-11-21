@testable import GinkgoCore
import XCTest

final class SizeLimitsParserTests: XCTestCase {
    private func limits(_ text: String) -> [Double?]? {
        SizeLimitsParser.parse(text).map { limits in
            [limits.maxWidthMm, limits.maxHeightMm, limits.maxDepthMm].map { $0.map { ($0 * 10).rounded() / 10 } }
        }
    }

    func testEveryUnit() {
        XCTAssertEqual(limits("no wider than 42 cm"), [420, nil, nil])
        XCTAssertEqual(limits("max width 420 mm"), [420, nil, nil])
        XCTAssertEqual(limits("at most 0.5 m tall"), [nil, 500, nil])
        XCTAssertEqual(limits("under 1.5 ft wide"), [457.2, nil, nil])
        XCTAssertEqual(limits("17 inches deep"), [nil, nil, 431.8])
        XCTAssertEqual(limits("12\" deep"), [nil, nil, 304.8])
        XCTAssertEqual(limits("2' high"), [nil, 609.6, nil])
        XCTAssertEqual(limits("width 40 centimetres"), [400, nil, nil])
    }

    func testNumbersWithoutAUnit() {
        XCTAssertEqual(limits("42 wide"), [420, nil, nil], "below 100 means centimetres")
        XCTAssertEqual(limits("max depth 300"), [nil, nil, 300], "100 and up means millimetres")
    }

    func testSeveralLimitsInOneSentence() {
        XCTAssertEqual(limits("Make it 42 cm wide and 45 cm tall, max depth 30"), [420, 450, 300])
        XCTAssertEqual(limits("no wider than 60 cm; actually under 50 cm wide"), [500, nil, nil], "the stricter limit wins")
        XCTAssertEqual(limits("Taller than nothing: height 1000"), [nil, 1000, nil])
    }

    func testNoLimitMeansNil() {
        XCTAssertNil(SizeLimitsParser.parse("make me a bench"))
        XCTAssertNil(SizeLimitsParser.parse("wide-ish please"), "a size word without a number")
        XCTAssertNil(SizeLimitsParser.parse("42 cm"), "a number without a size word")
        XCTAssertNil(SizeLimitsParser.parse("0 cm wide"), "zero is not a limit")
        XCTAssertNil(SizeLimitsParser.parse(""))
    }
}

final class VerifierTests: XCTestCase {
    private func recheck(_ id: String, _ dimension: GinkgoCore.Dimension, _ value: Double) throws -> VerifyOutcome {
        Verifier.recheck(plan: try Fixtures.planBench(), inventory: try Fixtures.inventory(), limits: nil,
                         measured: Remeasurement(sourcePartID: id, dimension: dimension, valueMm: value))
    }

    func testSameSizeIsVerified() throws {
        guard case let .verified(plan, validation) = try recheck("top", .width, 460) else { return XCTFail("expected verified") }
        XCTAssertEqual(plan.id, "plan-bench-1")
        XCTAssertTrue(validation.passes)
    }

    func testSmallerButStillEnoughIsVerified() throws {
        guard case let .verified(_, validation) = try recheck("top", .width, 410) else { return XCTFail("expected verified") }
        XCTAssertEqual(validation.verify.first, VerifyItem(dimension: .width, marginMm: 2, sourcePartID: "top"),
                       "the 52 mm margin shrank to 2 mm")
    }

    func testTooSmallAdjustsToABenchThatFits() throws {
        guard case let .adjusted(plan, validation, reason) = try recheck("top", .width, 405) else {
            return XCTFail("expected adjusted")
        }
        XCTAssertTrue(validation.passes)
        XCTAssertEqual(plan.template, .bench)
        XCTAssertLessThanOrEqual(try XCTUnwrap(plan.newParts.first { $0.role == .seat }).widthMm, 397)
        XCTAssertTrue(reason.hasPrefix("The new measurement changes the plan. seat: needs 408 × 308 mm"))
    }

    func testNothingOfTheSameKindFitsIsWithdrawn() throws {
        guard case let .withdrawn(reason) = try recheck("top", .width, 150) else { return XCTFail("expected withdrawn") }
        XCTAssertTrue(reason.hasSuffix("No bench fits the new measurement."), "a no-cut plan doesn't replace a bench silently")
    }

    func testBadMeasurementsAreWithdrawnWithAPlainMessage() throws {
        XCTAssertEqual(try recheck("top", .height, 0), .withdrawn(reason: "The new measurement must be more than 0 mm."))
        XCTAssertEqual(try recheck("top", .height, .nan), .withdrawn(reason: "The new measurement must be more than 0 mm."))
        XCTAssertEqual(try recheck("lid", .width, 400), .withdrawn(reason: "There is no part \"lid\" to re-measure."))
    }

    func testHeightIsRemeasuredToo() throws {
        guard case .verified = try recheck("side_left", .height, 400) else { return XCTFail("legs need 388 of 400 mm") }
        guard case .adjusted = try recheck("side_left", .height, 380) else { return XCTFail("legs no longer fit") }
    }
}
