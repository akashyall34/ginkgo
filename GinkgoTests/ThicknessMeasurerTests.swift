import simd
import XCTest
@testable import Ginkgo

/// A panel lying on a floor 45 cm from the phone, in a synthetic 192 × 144 depth frame: known thickness in,
/// that thickness out, and every way the reading can go wrong refused with its reason.
final class ThicknessMeasurerTests: XCTestCase {
    private let floorDepth: Float = 0.45
    /// The panel covers pixels x 60..<132, y 40..<104.
    private let panel = (minX: 60, maxX: 132, minY: 40, maxY: 104)

    private var corners: [ImagePoint] {
        let w: Float = 192, h: Float = 144
        let (x0, x1) = (Float(panel.minX) / w, Float(panel.maxX) / w)
        let (y0, y1) = (Float(panel.minY) / h, Float(panel.maxY) / h)
        return [ImagePoint(u: x0, v: y0), ImagePoint(u: x1, v: y0), ImagePoint(u: x1, v: y1), ImagePoint(u: x0, v: y1)]
    }

    private func onPanel(_ x: Int, _ y: Int) -> Bool {
        x >= panel.minX && x < panel.maxX && y >= panel.minY && y < panel.maxY
    }

    private func scene(thickness: Float, noise: Float = 0, seed: UInt64 = 7,
                       floor: ((Int, Int) -> Float)? = nil, face: ((Int, Int) -> Float)? = nil,
                       confidence: @escaping (Int, Int) -> UInt8 = { _, _ in 2 }) -> DepthSnapshot {
        var random = SeededGenerator(seed: seed)
        return makeSnapshot(depth: { x, y in
            let base = self.onPanel(x, y) ? (face?(x, y) ?? self.floorDepth - thickness) : (floor?(x, y) ?? self.floorDepth)
            return base + (noise == 0 ? 0 : (random.nextUniform() * 2 - 1) * noise)
        }, confidence: confidence)
    }

    private func measured(_ s: DepthSnapshot) throws -> ThicknessResult {
        try ThicknessMeasurer.measure(corners: corners, in: s).get()
    }

    // MARK: - Known answers

    func testAnEighteenMillimetrePanel() throws {
        let result = try measured(scene(thickness: 0.018))
        XCTAssertEqual(result.thickness, 0.018, accuracy: 0.0002)
        XCTAssertLessThan(result.uncertainty, 0.001)
        XCTAssertGreaterThan(result.floorPoints, PlaneMeasurer.minSurfacePoints)
    }

    func testAPlywoodBackAt6Millimetres() throws {
        XCTAssertEqual(try measured(scene(thickness: 0.006)).thickness, 0.006, accuracy: 0.0002)
    }

    func testRealisticDepthNoiseStillLandsWithinAMillimetre() throws {
        // ±2 mm per pixel, about what LiDAR gives at 45 cm; the median over thousands of points absorbs it.
        let result = try measured(scene(thickness: 0.019, noise: 0.002))
        XCTAssertEqual(result.thickness, 0.019, accuracy: 0.001)
        XCTAssertLessThanOrEqual(result.uncertainty, ThicknessMeasurer.maxUncertainty)
    }

    func testAPhoneHeldAtASlightAngleStillMeasuresTheTrueThickness() throws {
        // The whole scene tilted 4° (the phone not quite straight down): thickness is measured square to the floor.
        let slope = tan(Float(4) * .pi / 180) * 0.0025 // depth change per pixel
        let result = try measured(scene(thickness: 0.018,
                                        floor: { x, _ in self.floorDepth + Float(x) * slope },
                                        face: { x, _ in self.floorDepth - 0.018 + Float(x) * slope }))
        XCTAssertEqual(result.thickness, 0.018, accuracy: 0.0005)
    }

    // MARK: - Boundaries

    func testJustAboveTheThinnestReadableEdge() throws {
        XCTAssertEqual(try measured(scene(thickness: 0.0035)).thickness, 0.0035, accuracy: 0.0002)
    }

    func testBelowTheThinnestReadableEdgeIsRefused() {
        guard case .failure(.tooThin) = ThicknessMeasurer.measure(corners: corners, in: scene(thickness: 0.002)) else {
            return XCTFail("2 mm is below what LiDAR can tell from the floor")
        }
    }

    func testFarThickerThanAPanelIsRefused() {
        guard case .failure(.tooThick) = ThicknessMeasurer.measure(corners: corners, in: scene(thickness: 0.12)) else {
            return XCTFail("12 cm is a box, not a panel")
        }
    }

    // MARK: - Refusals, each with its reason

    func testAPanelThatIsntLyingFlatIsRefused() {
        // The face rises 10° across the panel while the floor stays level.
        let slope = tan(Float(10) * .pi / 180) * 0.0025
        let s = scene(thickness: 0, face: { x, _ in self.floorDepth - 0.018 - Float(x - self.panel.minX) * slope })
        guard case .failure(.notFlat(let degrees)) = ThicknessMeasurer.measure(corners: corners, in: s) else {
            return XCTFail("A tilted panel must not give a thickness")
        }
        XCTAssertGreaterThan(degrees, ThicknessMeasurer.maxTiltDegrees)
    }

    func testNoFloorAroundThePanelIsRefused() {
        // Depth unreliable everywhere off the panel (it fills the view, or lies on a shiny surface).
        let s = scene(thickness: 0.018, confidence: { x, y in self.onPanel(x, y) ? 2 : 0 })
        guard case .failure(.notEnoughFloor) = ThicknessMeasurer.measure(corners: corners, in: s) else {
            return XCTFail("No floor, no thickness")
        }
    }

    func testAnUnreadableTopIsRefused() {
        let s = scene(thickness: 0.018, confidence: { x, y in self.onPanel(x, y) ? 0 : 2 })
        guard case .failure(.notEnoughFace) = ThicknessMeasurer.measure(corners: corners, in: s) else {
            return XCTFail("No face, no thickness")
        }
    }

    func testDepthTooNoisyForAMillimetreAnswerIsRefused() {
        guard case .failure(.tooUncertain) = ThicknessMeasurer.measure(corners: corners,
                                                                        in: scene(thickness: 0.018, noise: 0.005)) else {
            return XCTFail("±5 mm noise can't give a thickness good enough for the sag check")
        }
    }

    func testTheWrongNumberOfCornersIsRefused() {
        guard case .failure(.notEnoughFace) = ThicknessMeasurer.measure(corners: Array(corners.prefix(3)),
                                                                         in: scene(thickness: 0.018)) else {
            return XCTFail("A face needs four corners")
        }
    }

    // MARK: - Pieces

    func testTheFloorRingStaysOffThePanelAndItsEdge() {
        let outline = corners.map { SIMD2($0.u * 192, $0.v * 144) }
        let ring = ThicknessMeasurer.ringPoints(around: outline, in: scene(thickness: 0.018))
        XCTAssertFalse(ring.isEmpty)
        XCTAssertTrue(ring.allSatisfy { abs(-$0.z - floorDepth) < 0.0001 }, "Every ring point is floor, none is panel")
    }

    func testMedianAndAngleHelpers() {
        XCTAssertEqual(ThicknessMeasurer.median([3, 1, 2]), 2)
        XCTAssertEqual(ThicknessMeasurer.median([4, 1, 3, 2]), 2.5)
        XCTAssertEqual(ThicknessMeasurer.median([]), 0)
        XCTAssertEqual(ThicknessMeasurer.degrees(between: SIMD3(0, 0, 1), and: SIMD3(0, 0, -1)), 0, accuracy: 0.01)
        XCTAssertEqual(ThicknessMeasurer.degrees(between: SIMD3(0, 0, 1), and: SIMD3(1, 0, 0)), 90, accuracy: 0.01)
    }

    func testEveryRefusalSaysWhatToDo() {
        let errors: [ThicknessError] = [.notEnoughFace(usable: 0, needed: 30), .notEnoughFloor(usable: 0, needed: 30),
                                        .notFlat(degrees: 9), .tooThin(meters: 0), .tooThick(meters: 1),
                                        .tooUncertain(meters: 0.01)]
        let texts = errors.map(\.explanation)
        XCTAssertFalse(texts.contains(where: \.isEmpty))
        XCTAssertEqual(Set(texts).count, texts.count)
    }
}
