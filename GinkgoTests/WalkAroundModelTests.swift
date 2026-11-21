import simd
import XCTest
@testable import Ginkgo

@MainActor
final class WalkAroundModelTests: XCTestCase {
    /// A solid-looking 50 × 40 × 60 cm box made of points on its sides and top.
    private var box: [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        for y in Swift.stride(from: Float(0.03), through: 0.6, by: 0.01) {
            for u in Swift.stride(from: Float(-0.25), through: 0.25, by: 0.01) {
                points += [SIMD3(u, y, -0.2), SIMD3(u, y, 0.2)]
            }
            for v in Swift.stride(from: Float(-0.2), through: 0.2, by: 0.01) {
                points += [SIMD3(-0.25, y, v), SIMD3(0.25, y, v)]
            }
        }
        // The top, which a real mesh scan always includes.
        for u in Swift.stride(from: Float(-0.25), through: 0.25, by: 0.01) {
            for v in Swift.stride(from: Float(-0.2), through: 0.2, by: 0.01) { points.append(SIMD3(u, 0.6, v)) }
        }
        return points
    }

    func testStartsScanningWithGuidance() {
        let model = WalkAroundModel()
        XCTAssertEqual(model.status, .scanning)
        XCTAssertTrue(model.instruction.contains("Walk slowly"))
    }

    func testAimingAtTheFurnitureMeasuresIt() throws {
        let model = WalkAroundModel()
        model.finish(points: box, floorY: 0, aim: SIMD3(0, 0.6, 0.2))
        guard case .measured(let result) = model.status else { return XCTFail("\(model.status)") }
        XCTAssertEqual(result.length, 0.5, accuracy: 0.005)
        XCTAssertEqual(result.width, 0.4, accuracy: 0.005)
        XCTAssertEqual(result.height, 0.6, accuracy: 0.005)
        XCTAssertEqual(model.instruction, "Measured from every side.")
    }

    func testMissingFloorOrAimSaysWhatToDo() {
        let model = WalkAroundModel()
        model.finish(points: box, floorY: nil, aim: SIMD3(0, 0.6, 0.2))
        XCTAssertEqual(model.status, .problem(WalkAroundModel.noFloorMessage))
        model.finish(points: box, floorY: 0, aim: nil)
        XCTAssertEqual(model.status, .problem(WalkAroundModel.noAimMessage))
        XCTAssertEqual(model.instruction, WalkAroundModel.noAimMessage)
    }

    func testAimingAtNothingIsAProblemNotACrash() {
        let model = WalkAroundModel()
        model.finish(points: box, floorY: 0, aim: SIMD3(3, 1, 3))
        XCTAssertEqual(model.status, .problem(WalkAroundModel.nothingThereMessage))
        model.finish(points: [], floorY: 0, aim: SIMD3(0, 0.5, 0))
        XCTAssertEqual(model.status, .problem(WalkAroundModel.nothingThereMessage))
    }

    func testTooLittleScannedAsksToWalkAroundMore() {
        let model = WalkAroundModel()
        let scrap = (0..<50).map { SIMD3(Float($0) * 0.005, 0.3, 0) }
        model.finish(points: scrap, floorY: 0, aim: SIMD3(0, 0.3, 0))
        XCTAssertEqual(model.status, .problem(BoxFitError.tooFewPoints(50).explanation))
    }

    func testRescanStartsOver() {
        let model = WalkAroundModel()
        model.finish(points: box, floorY: nil, aim: nil)
        model.rescan()
        XCTAssertEqual(model.status, .scanning)
    }

    func testSummaryIsLengthWidthHeightInCentimeters() {
        let fitted = FittedBox(length: 0.46, width: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 900)
        XCTAssertEqual(WalkAroundModel.summary(fitted), "46.0 × 40.0 × 58.0 cm ± 0.3 cm")
        let perfect = FittedBox(length: 0.5, width: 0.4, height: 0.6, baseCenter: .zero, yaw: 0, uncertainty: 0, pointCount: 900)
        XCTAssertEqual(WalkAroundModel.summary(perfect), "50.0 × 40.0 × 60.0 cm ± 0.1 cm", "Never claims zero error")
    }
}

@MainActor
final class WalkAroundProgressTests: XCTestCase {
    func testCoverageGrowsToFullAndStops() {
        XCTAssertEqual(WalkAroundModel.coverage(points: 0), 0)
        XCTAssertEqual(WalkAroundModel.coverage(points: WalkAroundModel.readyPoints / 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(WalkAroundModel.coverage(points: WalkAroundModel.readyPoints), 1)
        XCTAssertEqual(WalkAroundModel.coverage(points: WalkAroundModel.readyPoints * 5), 1)
        XCTAssertEqual(WalkAroundModel.coverage(points: -10), 0)
    }

    func testTheGuidanceChangesAsTheScanFillsIn() {
        XCTAssertEqual(WalkAroundModel.progressText(points: 0), "Keep walking around it")
        XCTAssertTrue(WalkAroundModel.progressText(points: WalkAroundModel.readyPoints * 3 / 4).hasPrefix("Almost there"))
        XCTAssertTrue(WalkAroundModel.progressText(points: WalkAroundModel.readyPoints).hasPrefix("Ready"))
    }
}

@MainActor
final class WalkAroundDepthTests: XCTestCase {
    /// Points on the four sides and top of an upright box centered on the origin, standing on the floor.
    private func shell(length: Float, width: Float, top: Float, from bottom: Float, step: Float) -> [SIMD3<Float>] {
        let (l, w) = (length / 2, width / 2)
        var points: [SIMD3<Float>] = []
        for y in stride(from: bottom, through: top, by: step) {
            for u in stride(from: -l, through: l, by: step) { points += [SIMD3(u, y, -w), SIMD3(u, y, w)] }
            for v in stride(from: -w, through: w, by: step) { points += [SIMD3(-l, y, v), SIMD3(l, y, v)] }
        }
        for u in stride(from: -l, through: l, by: step) {
            for v in stride(from: -w, through: w, by: step) { points.append(SIMD3(u, top, v)) }
        }
        return points
    }

    func testPreciseDepthCorrectsTheMeshBox() {
        // A mesh shell 3 cm too big on each side, and precise depth of the real 40 × 30 × 50 cm box.
        let mesh = shell(length: 0.46, width: 0.36, top: 0.53, from: 0.03, step: 0.01)
        let cloud = shell(length: 0.40, width: 0.30, top: 0.50, from: 0.02, step: 0.005)
        let model = WalkAroundModel()
        model.finish(points: mesh, floorY: 0, aim: SIMD3(0, 0.53, 0), cloud: cloud)
        guard case .measured(let box) = model.status else { return XCTFail("\(model.status)") }
        XCTAssertEqual(box.length, 0.40, accuracy: 0.005)
        XCTAssertEqual(box.width, 0.30, accuracy: 0.005)
        XCTAssertEqual(box.height, 0.50, accuracy: 0.005)
    }

    func testWithoutDepthTheMeshBoxStands() {
        let model = WalkAroundModel()
        model.finish(points: shell(length: 0.40, width: 0.30, top: 0.5, from: 0.03, step: 0.01), floorY: 0, aim: SIMD3(0, 0.5, 0))
        guard case .measured(let box) = model.status else { return XCTFail("\(model.status)") }
        XCTAssertEqual(box.length, 0.40, accuracy: 0.01)
    }
}
