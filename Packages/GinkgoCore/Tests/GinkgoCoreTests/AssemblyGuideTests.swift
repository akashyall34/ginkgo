@testable import GinkgoCore
import XCTest

/// Assembly from tested rules, on the sample bench (seat 400 × 300 on two 300 × 380 supports, all 19 mm solid wood).
final class AssemblyGuideTests: XCTestCase {
    private func guide() throws -> AssemblyGuide.Guide {
        AssemblyGuide.guide(for: try Fixtures.planBench(), inventory: try Fixtures.inventory())
    }

    // MARK: - Screws: the longest stock length that stays inside the panel

    func testA19MillimetrePanelTakesFiveEighthsInchScrews() throws {
        let screw = try XCTUnwrap(AssemblyGuide.screw(forThicknessMm: 19, material: .solidWood))
        XCTAssertEqual(screw.label, "#8 × 5/8 in")
        XCTAssertEqual(screw.lengthMm, 15.9)
    }

    func testTheClearanceBoundary() throws {
        // 15.9 + 3 = 18.9 mm: exactly enough for 5/8 in; 0.1 mm less drops to 1/2 in.
        XCTAssertEqual(AssemblyGuide.screw(forThicknessMm: 18.9, material: .plywood)?.label, "#8 × 5/8 in")
        XCTAssertEqual(AssemblyGuide.screw(forThicknessMm: 18.8, material: .plywood)?.label, "#8 × 1/2 in")
    }

    func testThickPanelsTakeLongerScrewsUpToOneInch() {
        XCTAssertEqual(AssemblyGuide.screw(forThicknessMm: 25, material: .solidWood)?.label, "#8 × 3/4 in")
        XCTAssertEqual(AssemblyGuide.screw(forThicknessMm: 60, material: .solidWood)?.label, "#8 × 1 in")
    }

    func testAPanelTooThinForAnyScrewGetsNone() {
        XCTAssertNil(AssemblyGuide.screw(forThicknessMm: 15, material: .solidWood), "12.7 + 3 > 15: it would poke through")
    }

    func testPilotHolesFollowTheMaterial() {
        XCTAssertTrue(AssemblyGuide.pilotHole(for: .solidWood).hasPrefix("Drill 5/64 in pilot holes (3/32 in if the wood is hard"))
        XCTAssertEqual(AssemblyGuide.pilotHole(for: .plywood), AssemblyGuide.pilotHole(for: .solidWood))
        XCTAssertTrue(AssemblyGuide.pilotHole(for: .particleboardMDF).contains("test pilot hole in a scrap"))
        XCTAssertTrue(AssemblyGuide.pilotHole(for: .plastic).contains("doesn't hold screws"))
        XCTAssertEqual(AssemblyGuide.pilotHole(for: .cardboard), AssemblyGuide.pilotHole(for: .plastic))
    }

    // MARK: - The sample bench

    func testTheBenchsHardwareIsCountedNotGuessed() throws {
        XCTAssertEqual(try guide().hardware, [
            HardwareItem(item: AssemblyGuide.bracket, quantity: 4),
            HardwareItem(item: "wood screw, #8 × 5/8 in", quantity: 16),
        ])
    }

    func testTheBenchsStepsInOrder() throws {
        let steps = try guide().steps
        XCTAssertEqual(steps.count, 7)
        XCTAssertEqual(steps[0].text, "Sand the cut edges smooth so nothing splinters.")
        XCTAssertEqual(steps[1].text, "Lay the seat upside down on a clean, flat floor.")
        XCTAssertEqual(steps[2].text, "Stand the left leg on the seat's underside, flush with its left end, square to it.")
        XCTAssertTrue(steps[3].text.contains("2 brackets in the inside corner, 40 mm in from the front and back edges"))
        XCTAssertTrue(steps[3].text.contains("Drive #8 × 5/8 in screws."))
        XCTAssertEqual(steps[6].text, "Turn it over onto its supports. Check it stands flat without rocking.")
    }

    func testEachStepSaysWhatIsInPlaceForThe3DView() throws {
        let placed = try guide().steps.map(\.placed)
        XCTAssertEqual(placed[0], [])
        XCTAssertEqual(placed[1], ["seat"])
        XCTAssertEqual(placed[2], ["seat", "leg_left"])
        XCTAssertEqual(placed.last, ["seat", "leg_left", "leg_right"])
    }

    func testNoWarningsWhenEveryJointCanBeScrewed() throws {
        XCTAssertEqual(try guide().warnings, [])
    }

    // MARK: - Positions from the layout

    private func part(_ name: String, x: Double, width: Double, role: Role) -> NewPart {
        NewPart(heightMm: 300, name: name, positionMm: Vector3(x: x, y: 0, z: 0), role: role,
                rotationDeg: Vector3(x: 0, y: 0, z: 0), sourcePartID: "p", spanMm: nil, widthMm: width)
    }

    func testASupportSetInFromTheEndSaysHowFar() {
        let seat = part("seat", x: 0, width: 400, role: .seat)
        // Outer face at -170 - 9 = -179: 21 mm in from the seat's left end at -200.
        XCTAssertEqual(AssemblyGuide.position(of: part("leg", x: -170, width: 300, role: .support), thicknessMm: 18, on: seat),
                       "21 mm in from its left end")
        XCTAssertEqual(AssemblyGuide.position(of: part("leg", x: 170, width: 300, role: .support), thicknessMm: 18, on: seat),
                       "21 mm in from its right end")
        XCTAssertEqual(AssemblyGuide.position(of: part("leg", x: 191, width: 300, role: .support), thicknessMm: 18, on: seat),
                       "flush with its right end")
    }

    // MARK: - Builds it can't screw, and builds with nothing to build

    func testAPanelTooThinIsGluedNotScrewedAndSaysSo() throws {
        let thin = try Fixtures.inventory()
        let inventory = Inventory(parts: thin.parts.map { $0.id == "side_left" ? $0.with(thicknessMm: 14) : $0 },
                                  scanID: thin.scanID)
        let guide = AssemblyGuide.guide(for: try Fixtures.planBench(), inventory: inventory)
        XCTAssertEqual(guide.warnings.count, 1)
        let warning = try XCTUnwrap(guide.warnings.first)
        XCTAssertTrue(warning.hasPrefix("Left leg: at 14 mm the panel is too thin"), warning)
        XCTAssertEqual(guide.hardware.first, HardwareItem(item: AssemblyGuide.bracket, quantity: 2), "Only the screwed joint")
    }

    func testAPlanThatReusesPanelsWholeHasNothingToAssemble() throws {
        let plan = try Fixtures.planBench().with(template: .noCut)
        let guide = AssemblyGuide.guide(for: plan, inventory: try Fixtures.inventory())
        XCTAssertEqual(guide.steps.count, 1)
        XCTAssertEqual(guide.hardware, [])
    }

    func testAPlanWithNoSeatOnSupportsHasNoTestedJoint() throws {
        let plan = try Fixtures.planBench()
        let loose = plan.with(newParts: plan.newParts.filter { $0.role != .seat })
        let guide = AssemblyGuide.guide(for: loose, inventory: try Fixtures.inventory())
        XCTAssertEqual(guide.hardware, [])
        XCTAssertTrue(guide.warnings.first?.contains("no tested joint") == true)
    }
}

final class PartNameFormatTests: XCTestCase {
    func testPartNamesInPlainWords() {
        XCTAssertEqual(Format.partName("leg_left"), "left leg")
        XCTAssertEqual(Format.partName("drawer_front"), "drawer front")
        XCTAssertEqual(Format.partName("seat"), "seat")
        XCTAssertEqual(Format.partName("right"), "right")
        XCTAssertEqual("left leg".capitalizedFirst, "Left leg")
        XCTAssertEqual("".capitalizedFirst, "")
    }
}
