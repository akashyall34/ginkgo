import GinkgoCore
import XCTest
@testable import Ginkgo

final class SamplePiecesTests: XCTestCase {
    func testAllFourSamplesShipWithTheApp() {
        let samples = SamplePiece.all()
        XCTAssertEqual(samples.map(\.name), ["Nightstand", "Stool", "Drawer cart", "Box"])
        XCTAssertTrue(samples.allSatisfy { !$0.inventory.parts.isEmpty })
        XCTAssertEqual(Set(samples.map(\.id)).count, 4, "Each sample has its own id")
    }

    func testTheSummaryCountsPartsAndNamesTheBiggest() throws {
        let part = { (id: String, w: Double, h: Double) in
            Part(damaged: false, heightMm: h, id: id, keepOuts: [], material: .plywood, thicknessMm: 18, type: .side,
                 widthMm: w)
        }
        let two = SamplePiece(id: "a", name: "A", inventory: Inventory(parts: [part("small", 100, 100),
                                                                              part("big", 600, 400)], scanID: "s"))
        XCTAssertEqual(two.summary, "2 parts · biggest 60 × 40 cm")
        let one = SamplePiece(id: "b", name: "B", inventory: Inventory(parts: [part("only", 300, 200)], scanID: "s"))
        XCTAssertEqual(one.summary, "1 part · biggest 30 × 20 cm")
    }

    func testTheSampleNightstandCanStillBeBuiltInto() throws {
        let nightstand = try XCTUnwrap(SamplePiece.all().first)
        XCTAssertNotNil(RuleBasedPlanner.bench(inventory: nightstand.inventory),
                        "The first sample leads somewhere: a bench that passes the validator")
    }

    func testASampleWithNoPartsIsLeftOut() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("samples-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(#"{"scan_id": "s", "parts": []}"#.utf8).write(to: folder.appendingPathComponent("empty.json"))
        try Data("not json".utf8).write(to: folder.appendingPathComponent("broken.json"))
        let bundle = try XCTUnwrap(Bundle(url: folder) ?? Bundle(path: folder.path))
        let found = SamplePiece.all(bundle: bundle, files: [SamplePiece.Source(id: "a", name: "A", file: "empty"),
                                                                  SamplePiece.Source(id: "b", name: "B", file: "broken")])
        XCTAssertEqual(found, [], "An empty or unreadable file never becomes a card")
    }

    func testAMissingFileIsLeftOutNotShownBroken() {
        XCTAssertEqual(SamplePiece.all(bundle: Bundle(for: SamplePiecesTests.self)).count, 0,
                       "The test bundle has no sample files")
    }
}
