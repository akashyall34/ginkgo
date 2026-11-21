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
        XCTAssertEqual(result.width, 0.5, accuracy: 0.005)
        XCTAssertEqual(result.depth, 0.4, accuracy: 0.005)
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

    func testSummaryIsWidthHeightDepthInCentimeters() {
        let fitted = FittedBox(width: 0.46, depth: 0.40, height: 0.58, baseCenter: .zero, yaw: 0, uncertainty: 0.003, pointCount: 900)
        XCTAssertEqual(WalkAroundModel.summary(fitted), "46.0 × 58.0 × 40.0 cm ± 0.3 cm")
        let perfect = FittedBox(width: 0.5, depth: 0.4, height: 0.6, baseCenter: .zero, yaw: 0, uncertainty: 0, pointCount: 900)
        XCTAssertEqual(WalkAroundModel.summary(perfect), "50.0 × 60.0 × 40.0 cm ± 0.1 cm", "Never claims zero error")
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
