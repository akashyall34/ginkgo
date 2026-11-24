import GinkgoCore
import XCTest
@testable import Ginkgo

/// Scanning each cut piece of the sample bench (seat 400 × 300, supports 300 × 380) before assembly.
final class CutCheckModelTests: XCTestCase {
    private func model() throws -> CutCheckModel {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
        let bench = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        return CutCheckModel(plan: bench.plan, result: bench.validation, inventory: inventory)
    }

    /// The planned size of a piece, in meters, as a perfect scan would report it.
    private func planned(_ model: CutCheckModel, _ piece: String, plusMm: Double = 0) throws -> (Float, Float) {
        let part = try XCTUnwrap(model.plan.newParts.first { $0.name == piece })
        return (Float((part.widthMm + plusMm) / 1000), Float(part.heightMm / 1000))
    }

    func testItStartsWithEveryCutPieceToScan() throws {
        let m = try model()
        XCTAssertFalse(m.pieces.isEmpty)
        XCTAssertEqual(m.remaining, m.pieces.count)
        XCTAssertFalse(m.readyToAssemble)
        XCTAssertEqual(m.summary, "Scan each piece after cutting: \(m.pieces.count) of \(m.pieces.count) to go.")
    }

    func testEveryPieceAtItsPlannedSizeIsReadyToAssemble() throws {
        var m = try model()
        for piece in m.pieces {
            let (w, h) = try planned(m, piece)
            m.record(piece: piece, widthMeters: w, heightMeters: h)
        }
        XCTAssertEqual(m.remaining, 0)
        XCTAssertTrue(m.readyToAssemble)
        XCTAssertEqual(m.summary, "Every piece checks out. Ready to assemble.")
    }

    func testATooLongPieceBlocksAssemblyUntilTrimmed() throws {
        var m = try model()
        for piece in m.pieces {
            let (w, h) = try planned(m, piece, plusMm: piece == m.pieces[0] ? 8 : 0)
            m.record(piece: piece, widthMeters: w, heightMeters: h)
        }
        guard case .trim = m.results[m.pieces[0]]?.verdict else { return XCTFail("\(String(describing: m.results))") }
        XCTAssertFalse(m.readyToAssemble)
        XCTAssertEqual(m.summary, "Fix the pieces marked below, then scan them again.")
    }

    func testMismatchedSupportsBlockAssembly() throws {
        var m = try model()
        let supports = m.plan.newParts.filter { $0.role == .support }.map(\.name)
        try XCTSkipIf(supports.count < 2, "The sample bench has two supports")
        for piece in m.pieces {
            let part = try XCTUnwrap(m.plan.newParts.first { $0.name == piece })
            let extra: Double = piece == supports[1] ? 1.5 : 0  // within its own tolerance, but...
            m.record(piece: piece, widthMeters: Float(part.widthMm / 1000), heightMeters: Float((part.heightMm + extra) / 1000))
        }
        XCTAssertTrue(m.readyToAssemble, "1.5 mm apart is within tolerance")
        let tall = try XCTUnwrap(m.plan.newParts.first { $0.name == supports[1] })
        m.record(piece: supports[1], widthMeters: Float(tall.widthMm / 1000), heightMeters: Float((tall.heightMm + 2) / 1000))
        m.record(piece: supports[0], widthMeters: Float(tall.widthMm / 1000), heightMeters: Float((tall.heightMm - 1.5) / 1000))
        XCTAssertFalse(m.supportWarnings.isEmpty, "3.5 mm apart: the bench would wobble")
        XCTAssertFalse(m.readyToAssemble)
    }

    func testScansOfUnknownPiecesOrNonsenseAreIgnored() throws {
        var m = try model()
        m.record(piece: "shelf", widthMeters: 0.4, heightMeters: 0.3)
        m.record(piece: m.pieces[0], widthMeters: 0, heightMeters: 0.3)
        XCTAssertTrue(m.results.isEmpty)
    }

    func testScansAreKeptToATenthOfAMillimetre() throws {
        var m = try model()
        m.record(piece: m.pieces[0], widthMeters: 0.40012, heightMeters: 0.29996)
        XCTAssertEqual(m.scanned[m.pieces[0]]?.widthMm, 400.1)
        XCTAssertEqual(m.scanned[m.pieces[0]]?.heightMm, 300)
    }

    func testAPlanWithNothingCutHasNothingToCheck() throws {
        let m = try model()
        let none = ValidationResult(passes: true, placements: [], planID: "p", reusePercent: 0, sag: [], verify: [],
                                    violations: [])
        let empty = CutCheckModel(plan: m.plan, result: none, inventory: m.inventory)
        XCTAssertEqual(empty.pieces, [])
        XCTAssertEqual(empty.summary, "Nothing was cut, so there's nothing to check.")
    }

    func testVerdictsShowAsTheirColourAndIcon() {
        XCTAssertEqual(CutCheckView.icon(.good), "checkmark.circle.fill")
        XCTAssertEqual(CutCheckView.icon(.useAsIs(shortByMm: 3)), "checkmark.circle.fill")
        XCTAssertEqual(CutCheckView.icon(.trim(widthMm: 1, heightMm: 0)), "scissors")
        XCTAssertEqual(CutCheckView.icon(.recut(reason: "")), "xmark.circle.fill")
    }
}
