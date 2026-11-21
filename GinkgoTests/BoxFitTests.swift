import simd
import XCTest
@testable import Ginkgo

private extension SeededGenerator {
    mutating func between(_ low: Float, _ high: Float) -> Float { low + (high - low) * nextUniform() }
}

final class BoxFitTests: XCTestCase {
    /// Points on the four sides and the top of an upright box standing on the floor,
    /// like a mesh scan of a cabinet (the bottom touches the floor and isn't seen).
    private func boxSurface(length: Float, width: Float, height: Float, yaw: Float, center: SIMD2<Float> = .zero,
                            floorY: Float = 0, spacing: Float = 0.01, noise: Float = 0,
                            rng: inout SeededGenerator) -> [SIMD3<Float>] {
        var local: [SIMD3<Float>] = []
        func range(_ length: Float) -> [Float] { Swift.stride(from: -length / 2, through: length / 2, by: spacing).map { $0 } }
        let heights = Swift.stride(from: Float(0.02), through: height, by: spacing).map { $0 }
        for y in heights {
            for u in range(length) { local += [SIMD3(u, y, -width / 2), SIMD3(u, y, width / 2)] }
            for v in range(width) { local += [SIMD3(-length / 2, y, v), SIMD3(length / 2, y, v)] }
        }
        for u in range(length) { for v in range(width) { local.append(SIMD3(u, height, v)) } }
        let (c, s) = (cos(yaw), sin(yaw))
        return local.map { p in
            let jitter = SIMD3(rng.between(-noise, noise), rng.between(-noise, noise), rng.between(-noise, noise))
            return SIMD3(p.x * c - p.z * s + center.x, p.y + floorY, p.x * s + p.z * c + center.y) + (noise > 0 ? jitter : .zero)
        }
    }

    private func floor(size: Float = 2, y: Float = 0) -> [SIMD3<Float>] {
        Swift.stride(from: -size, through: size, by: 0.02).flatMap { x in
            Swift.stride(from: -size, through: size, by: 0.02).map { z in SIMD3(x, y, z) }
        }
    }

    private func angleDifference(_ a: Float, _ b: Float) -> Float {
        let d = abs(a - b).truncatingRemainder(dividingBy: .pi)
        return min(d, .pi - d)
    }

    // MARK: box fit

    func testAPieceTurnedThirtyDegreesIsMeasuredToTheMillimeter() throws {
        var rng = SeededGenerator(seed: 1)
        let points = boxSurface(length: 0.46, width: 0.40, height: 0.58, yaw: .pi / 6, center: SIMD2(0.3, -0.2), rng: &rng)
        let box = try BoxFit.fit(points, floorY: 0)
        XCTAssertEqual(box.length, 0.46, accuracy: 0.003)
        XCTAssertEqual(box.width, 0.40, accuracy: 0.003)
        XCTAssertEqual(box.height, 0.58, accuracy: 0.003)
        XCTAssertLessThan(angleDifference(box.yaw, .pi / 6), 0.01)
        XCTAssertEqual(box.baseCenter.x, 0.3, accuracy: 0.003)
        XCTAssertEqual(box.baseCenter.z, -0.2, accuracy: 0.003)
        XCTAssertLessThan(box.uncertainty, 0.003, "Clean points fit the faces closely")
    }

    func testSquareOnAndNearlyQuarterTurnAreBothFound() throws {
        for yaw: Float in [0, .pi / 2 - 0.02, 1.2] {
            var rng = SeededGenerator(seed: 2)
            let box = try BoxFit.fit(boxSurface(length: 0.8, width: 0.3, height: 1.1, yaw: yaw, rng: &rng), floorY: 0)
            XCTAssertEqual(box.length, 0.8, accuracy: 0.004, "yaw \(yaw)")
            XCTAssertEqual(box.width, 0.3, accuracy: 0.004, "yaw \(yaw)")
            XCTAssertLessThan(angleDifference(box.yaw, yaw), 0.01, "yaw \(yaw)")
        }
    }

    func testLengthIsAlwaysTheLongerSide() throws {
        var rng = SeededGenerator(seed: 3)
        let box = try BoxFit.fit(boxSurface(length: 0.3, width: 0.7, height: 0.5, yaw: 0.4, rng: &rng), floorY: 0)
        XCTAssertEqual(box.length, 0.7, accuracy: 0.004)
        XCTAssertEqual(box.width, 0.3, accuracy: 0.004)
        XCTAssertLessThan(angleDifference(box.yaw, 0.4 + .pi / 2), 0.01, "Yaw follows the length")
    }

    func testHeightIsMeasuredFromTheFloorNotTheLowestPoint() throws {
        var rng = SeededGenerator(seed: 4)
        let points = boxSurface(length: 0.5, width: 0.4, height: 0.6, yaw: 0.2, floorY: -1.3, rng: &rng)
        XCTAssertEqual(try BoxFit.fit(points, floorY: -1.3).height, 0.6, accuracy: 0.003)
    }

    func testSensorNoiseShowsUpInTheUncertaintyNotTheSize() throws {
        var rng = SeededGenerator(seed: 5)
        let points = boxSurface(length: 0.46, width: 0.40, height: 0.58, yaw: 0.5, noise: 0.006, rng: &rng)
        let box = try BoxFit.fit(points, floorY: 0)
        XCTAssertEqual(box.length, 0.46, accuracy: 0.01)
        XCTAssertEqual(box.width, 0.40, accuracy: 0.01)
        XCTAssertGreaterThan(box.uncertainty, 0.002, "Noisy points must not claim millimeter precision")
        XCTAssertLessThan(box.uncertainty, 0.01)
    }

    func testAFewStrayPointsDoNotGrowTheBox() throws {
        var rng = SeededGenerator(seed: 6)
        var points = boxSurface(length: 0.46, width: 0.40, height: 0.58, yaw: 0.3, rng: &rng)
        let strays = (0..<points.count / 200).map { _ in
            SIMD3(rng.between(0.5, 0.9), rng.between(0.1, 1.2), rng.between(0.5, 0.9))
        }
        points += strays
        let box = try BoxFit.fit(points, floorY: 0)
        XCTAssertEqual(box.length, 0.46, accuracy: 0.01)
        XCTAssertEqual(box.height, 0.58, accuracy: 0.01)
    }

    func testTooFewPointsIsRefused() {
        let points = (0..<BoxFit.minimumPoints - 1).map { SIMD3(Float($0) * 0.001, 0.1, 0) }
        XCTAssertThrowsError(try BoxFit.fit(points, floorY: 0)) {
            XCTAssertEqual($0 as? BoxFitError, .tooFewPoints(BoxFit.minimumPoints - 1))
        }
        XCTAssertFalse(BoxFitError.tooFewPoints(0).explanation.isEmpty)
    }

    // MARK: isolating the furniture

    func testOnlyTheAimedAtFurnitureIsKeptFromARoom() throws {
        var rng = SeededGenerator(seed: 7)
        let piece = boxSurface(length: 0.46, width: 0.40, height: 0.58, yaw: 0.3, rng: &rng)
        let chair = boxSurface(length: 0.45, width: 0.45, height: 0.9, yaw: 0, center: SIMD2(1.0, 0), rng: &rng)
        let room = floor() + piece + chair
        let kept = FurnitureIsolation.isolate(room, seed: SIMD3(0, 0.58, 0), floorY: 0)
        XCTAssertEqual(kept.count, piece.filter { $0.y > 0.015 }.count, "Floor and chair are left out")
        let box = try BoxFit.fit(kept, floorY: 0)
        XCTAssertEqual(box.length, 0.46, accuracy: 0.004)
        XCTAssertEqual(box.height, 0.58, accuracy: 0.004)
    }

    func testAimingJustOffTheSurfaceStillFindsIt() {
        var rng = SeededGenerator(seed: 8)
        let piece = boxSurface(length: 0.46, width: 0.40, height: 0.58, yaw: 0, rng: &rng)
        let kept = FurnitureIsolation.isolate(piece, seed: SIMD3(0, 0.65, 0), floorY: 0)
        XCTAssertFalse(kept.isEmpty)
    }

    func testAimingAtEmptySpaceFindsNothing() {
        var rng = SeededGenerator(seed: 9)
        let piece = boxSurface(length: 0.46, width: 0.40, height: 0.58, yaw: 0, rng: &rng)
        XCTAssertEqual(FurnitureIsolation.isolate(piece, seed: SIMD3(2, 1, 2), floorY: 0), [])
        XCTAssertEqual(FurnitureIsolation.isolate(floor(), seed: SIMD3(0, 0, 0), floorY: 0), [], "Only floor: nothing")
    }

    func testPercentileEnds() {
        XCTAssertEqual(BoxFit.percentile([3, 1, 2], 0), 1)
        XCTAssertEqual(BoxFit.percentile([3, 1, 2], 1), 3)
        XCTAssertEqual(BoxFit.percentile([3, 1, 2], 0.5), 2)
    }
}
