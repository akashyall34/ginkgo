@testable import GinkgoCore
import XCTest

/// A seat must not reach past its supports: a person on that edge would tip the bench. Layout convention: x side to
/// side, z front to back; a seat lies flat (90, 0, 0), supports stand sideways (0, 90, 0). All panels 19 mm.
final class OverhangTests: XCTestCase {
    private func parts() throws -> [String: Part] {
        Dictionary(try Fixtures.inventory().parts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// `at` is (x position, width, height) in mm; seats lie flat, supports stand sideways.
    private func newPart(_ name: String, _ role: Role, from source: String, at size: [Double]) -> NewPart {
        let rotation = role == .seat ? Vector3(x: 90, y: 0, z: 0) : Vector3(x: 0, y: 90, z: 0)
        return NewPart(heightMm: size[2], name: name, positionMm: Vector3(x: size[0], y: 0, z: 0), role: role,
                       rotationDeg: rotation, sourcePartID: source, spanMm: role == .seat ? 362 : nil, widthMm: size[1])
    }

    /// A 400 × 300 seat on two 300-deep supports whose outer faces are `inset` mm in from the seat's ends.
    private func bench(inset: Double, supportDepth: Double = 300, template: Template = .bench) -> Plan {
        let half = 9.5
        let parts = [
            newPart("seat", .seat, from: "top", at: [0, 400, 300]),
            newPart("leg_left", .support, from: "side_left", at: [-200 + inset + half, supportDepth, 380]),
            newPart("leg_right", .support, from: "side_right", at: [200 - inset - half, supportDepth, 380]),
        ]
        return Plan(hardware: [], id: "p", newParts: parts, overallMm: nil, scanID: "s", source: .ginkgo, steps: [],
                    template: template)
    }

    private func check(_ plan: Plan) throws -> [Violation] {
        Overhang.violations(plan, parts: try parts(), placed: Set(plan.newParts.map(\.name)))
    }

    func testSupportsFlushWithTheEndsStandFirm() throws {
        XCTAssertEqual(try check(bench(inset: 0)), [])
    }

    func testASupportSetFiftyMillimetresInTipsAtThatEnd() throws {
        let violations = try check(bench(inset: 50))
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.code, .unstable)
        XCTAssertTrue(violations.first?.message.hasPrefix("seat: overhangs its supports by 50 mm at the") == true,
                      violations.first?.message ?? "")
    }

    func testTheToleranceIsOneMillimetre() throws {
        XCTAssertEqual(try check(bench(inset: 1)), [], "1 mm is within tolerance")
        XCTAssertEqual(try check(bench(inset: 1.5)).count, 1, "1.5 mm is past it")
    }

    func testASeatDeeperThanItsSupportsTipsFrontToBack() throws {
        let violations = try check(bench(inset: 0, supportDepth: 200))
        XCTAssertTrue(violations.first?.message.contains("overhangs its supports by 50 mm at the back edge") == true
                      || violations.first?.message.contains("overhangs its supports by 50 mm at the front edge") == true,
                      violations.first?.message ?? "")
    }

    func testAWholePartReuseIsNeverJudged() throws {
        XCTAssertEqual(try check(bench(inset: 80, template: .noCut)), [])
    }

    func testAPlanWhosePartsWerentAllPlacedIsntJudged() throws {
        let plan = bench(inset: 80)
        XCTAssertEqual(Overhang.violations(plan, parts: try parts(), placed: ["seat", "leg_left"]), [])
    }
}
