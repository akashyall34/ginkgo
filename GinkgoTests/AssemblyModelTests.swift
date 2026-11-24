import GinkgoCore
import XCTest
@testable import Ginkgo

/// Step-by-step assembly of the sample bench: the steps from tested rules, and what the 3D view shows at each.
final class AssemblyModelTests: XCTestCase {
    private func model() throws -> AssemblyModel {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "inventory", withExtension: "json"))
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
        let bench = try XCTUnwrap(RuleBasedPlanner.bench(inventory: inventory))
        return AssemblyModel(plan: bench.plan, inventory: inventory)
    }

    func testItStartsOnStepOneWithNothingPlaced() throws {
        let m = try model()
        XCTAssertEqual(m.title, "Step 1 of \(m.steps.count)")
        XCTAssertTrue(m.isFirst)
        XCTAssertTrue(m.visible.isEmpty, "Sanding comes first: nothing is in place yet")
    }

    func testEachStepShowsWhatsInPlaceWithTheNewestPieceHighlighted() throws {
        var m = try model()
        m.next()
        XCTAssertEqual(m.visible.map(\.piece.name), [m.current?.placed.first].compactMap { $0 })
        XCTAssertTrue(m.visible.allSatisfy(\.isNew), "The seat is new at this step")
        m.next()
        let names = m.visible.map(\.piece.name)
        XCTAssertEqual(Set(names), Set(m.current?.placed ?? []))
        XCTAssertEqual(m.visible.filter(\.isNew).count, 1, "Only the support placed in this step is highlighted")
    }

    func testTheLastStepShowsTheWholeBuild() throws {
        var m = try model()
        for _ in 0..<20 { m.next() }
        XCTAssertTrue(m.isLast)
        XCTAssertEqual(m.visible.count, m.scene.pieces.count)
        XCTAssertFalse(m.visible.contains(where: \.isNew), "Turning it over adds no piece")
    }

    func testBackAndNextStayInBounds() throws {
        var m = try model()
        m.previous()
        XCTAssertEqual(m.index, 0)
        m.next()
        m.previous()
        XCTAssertEqual(m.index, 0)
    }

    func testHardwareComesFromTheRulesNotTheAI() throws {
        let m = try model()
        XCTAssertTrue(m.guide.hardware.contains { $0.item == AssemblyGuide.bracket })
        XCTAssertTrue(m.guide.hardware.contains { $0.item.hasPrefix("wood screw, #8 × ") })
    }
}
