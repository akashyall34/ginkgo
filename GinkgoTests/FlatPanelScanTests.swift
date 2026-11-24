import GinkgoCore
import XCTest
@testable import Ginkgo

/// Flat-panel mode end to end on the demo scene (a 19.05 × 12 cm panel 18 mm above the floor): capture, pick the
/// face, read the width, height and thickness; and how Verify records a scanned thickness.
@MainActor
final class FlatPanelScanTests: XCTestCase {
    private var faceCenter: CGPoint {
        let c = DemoScene.portraitCorners
        return CGPoint(x: c.map(\.x).reduce(0, +) / 4, y: c.map(\.y).reduce(0, +) / 4)
    }

    private func scanned(measuresThickness: Bool) -> ScanModel {
        let model = ScanModel(source: DemoFrameSource(), measuresThickness: measuresThickness)
        model.capture()
        model.selectFace(at: faceCenter)
        return model
    }

    // MARK: - The demo scene

    func testTheDemoPanelSitsEighteenMillimetresAboveTheFloor() {
        let depth = DemoScene.depth(width: 192, height: 144)
        XCTAssertEqual(depth[72 * 192 + 96], DemoScene.distanceMeters, "The middle of the frame is the panel")
        XCTAssertEqual(depth[0], DemoScene.distanceMeters + DemoScene.thicknessMeters, "The corner is floor")
    }

    // MARK: - Scan

    func testFlatPanelModeReadsTheThicknessWithTheSize() throws {
        let model = scanned(measuresThickness: true)
        guard case .measured(let size) = model.status else { return XCTFail("\(model.status)") }
        XCTAssertEqual(size.width, DemoScene.widthMeters, accuracy: 0.002, "The size is unchanged by the floor")
        let thickness = try XCTUnwrap(model.thickness, model.thicknessProblem ?? "no thickness")
        XCTAssertEqual(thickness.thickness, DemoScene.thicknessMeters, accuracy: 0.0005)
        XCTAssertNil(model.thicknessProblem)
    }

    func testTheNormalScanDoesntMeasureThickness() {
        let model = scanned(measuresThickness: false)
        guard case .measured = model.status else { return XCTFail("\(model.status)") }
        XCTAssertNil(model.thickness)
        XCTAssertNil(model.thicknessProblem)
    }

    func testRetakeClearsTheThickness() {
        let model = scanned(measuresThickness: true)
        model.retake()
        XCTAssertNil(model.thickness)
        XCTAssertNil(model.thicknessProblem)
    }

    func testAFlatFrameWithNoStepGivesAReasonNotANumber() throws {
        // Everything at one depth: the panel's edge can't be told from the floor.
        let flat = try XCTUnwrap(DemoScene.frame())
        let snapshot = try XCTUnwrap(DepthSnapshot(width: 192, height: 144,
                                                   depth: Array(repeating: 0.5, count: 192 * 144),
                                                   confidence: Array(repeating: 2, count: 192 * 144),
                                                   intrinsics: DemoScene.intrinsics))
        let frame = CapturedFrame(image: flat.image, confidenceOverlay: flat.confidenceOverlay, snapshot: snapshot)
        let model = ScanModel(source: DemoFrameSource(makeFrame: { frame }), measuresThickness: true)
        model.capture()
        model.selectFace(at: faceCenter)
        guard case .measured = model.status else { return XCTFail("The size still stands: \(model.status)") }
        XCTAssertNil(model.thickness)
        XCTAssertEqual(model.thicknessProblem, ThicknessError.tooThin(meters: 0).explanation)
    }

    func testFlatPanelModeHasItsOwnInstruction() {
        XCTAssertTrue(ScanModel(source: DemoFrameSource(), measuresThickness: true).instruction.hasPrefix("Lay the panel flat"))
        XCTAssertTrue(ScanModel(source: DemoFrameSource()).instruction.hasPrefix("Aim at one flat face"))
    }

    // MARK: - Wording

    func testThicknessReadsInMillimetres() {
        XCTAssertEqual(MeasurementFormat.thickness(meters: 0.018, uncertaintyMeters: 0.0009), "18.0 mm thick ± 0.9 mm")
        XCTAssertEqual(MeasurementFormat.spokenThickness(meters: 0.0185, uncertaintyMeters: 0.001),
                       "18.5 millimeters thick, plus or minus 1.0")
    }

    // MARK: - Verify records how it was measured

    private func verify() throws -> VerifyModel {
        let box = FittedBox(length: 0.46, width: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.002,
                            pointCount: 4000)
        let model = try LivePlan.proof(from: box, scanID: "s", material: .solidWood).get()
        return VerifyModel(plan: model.plan, inventory: model.inventory, result: model.result)
    }

    func testAScannedThicknessIsRecordedAsScanned() throws {
        var v = try verify()
        XCTAssertEqual(v.checks.first?.dimension, .thickness)
        v.record(18.4, for: 0, scanned: true)
        XCTAssertEqual(v.inventory.parts.first { $0.id == "top" }?.thicknessSource, .scanned)
    }

    func testATypedThicknessIsRecordedAsTape() throws {
        var v = try verify()
        v.record(18.4, for: 0)
        XCTAssertEqual(v.inventory.parts.first { $0.id == "top" }?.thicknessSource, .tape)
    }
}
