import CoreGraphics
import XCTest
@testable import Ginkgo

final class SubjectMaskTests: XCTestCase {
    private func mask(_ width: Int, _ height: Int, on: (Int, Int) -> Bool) -> SubjectMask {
        var pixels: [Bool] = []
        for y in 0..<height { for x in 0..<width { pixels.append(on(x, y)) } }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }

    private func assertCorners(_ actual: [CGPoint]?, _ expected: [CGPoint], line: UInt = #line) {
        guard let actual, actual.count == 4 else { return XCTFail("No corners", line: line) }
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.x, e.x, accuracy: 0.011, "\(actual)", line: line)
            XCTAssertEqual(a.y, e.y, accuracy: 0.011, "\(actual)", line: line)
        }
    }

    func testAnUprightRectangleGivesItsFourCornersInOrder() {
        // Subject covers x 20..<80, y 30..<70 of a 100 × 100 photo.
        let m = mask(100, 100) { (20..<80).contains($0) && (30..<70).contains($1) }
        assertCorners(m.corners, [CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.8, y: 0.3), CGPoint(x: 0.8, y: 0.7), CGPoint(x: 0.2, y: 0.7)])
    }

    func testAFaceSeenAtAnAngleKeepsItsSlantedCorners() {
        // A trapezoid: narrower at the top, like a face tilted away.
        let m = mask(100, 100) { x, y in
            guard (20..<80).contains(y) else { return false }
            let inset = (80 - y) / 4
            return x >= 20 + inset && x < 80 - inset
        }
        let c = m.corners ?? []
        XCTAssertEqual(c.count, 4)
        XCTAssertGreaterThan(c[0].x, c[3].x, "Top-left sits further in than bottom-left")
        XCTAssertLessThan(c[1].x, c[2].x, "Top-right sits further in than bottom-right")
        XCTAssertTrue(DetectedQuad(corners: c).isConvex)
    }

    func testCornersAreAValidShapeForMeasuring() {
        let m = mask(64, 48) { (5..<60).contains($0) && (4..<40).contains($1) }
        XCTAssertTrue(DetectedQuad(corners: m.corners ?? []).isConvex)
    }

    func testAnEmptyMaskHasNoCorners() {
        XCTAssertNil(mask(10, 10) { _, _ in false }.corners)
    }

    func testASinglePixelStillHasAPosition() {
        let c = mask(10, 10) { $0 == 3 && $1 == 7 }.corners
        XCTAssertEqual(c?.first, CGPoint(x: 0.35, y: 0.75))
    }
}

/// Returns a fixed mask, and records where it was asked to look.
private final class FakeLifter: SubjectLifting {
    let mask: SubjectMask?
    var taps: [CGPoint] = []
    init(_ mask: SubjectMask?) { self.mask = mask }
    func lift(from image: CGImage, at point: CGPoint) -> SubjectMask? { taps.append(point); return mask }
}

/// One-tap lifting on the Scan screen, with the demo scene and a stand-in for Vision.
@MainActor
final class OneTapLiftTests: XCTestCase {
    /// The demo face's area on the portrait photo, as a mask.
    private var demoFaceMask: SubjectMask {
        let c = DemoScene.portraitCorners
        let (minX, maxX) = (c.map(\.x).min() ?? 0, c.map(\.x).max() ?? 1)
        let (minY, maxY) = (c.map(\.y).min() ?? 0, c.map(\.y).max() ?? 1)
        var pixels: [Bool] = []
        for y in 0..<200 {
            for x in 0..<200 {
                let (u, v) = ((Double(x) + 0.5) / 200, (Double(y) + 0.5) / 200)
                pixels.append(u >= minX && u <= maxX && v >= minY && v <= maxY)
            }
        }
        return SubjectMask(width: 200, height: 200, pixels: pixels)
    }

    func testTappingOffTheOutlinesLiftsTheFurnitureAndMeasuresIt() throws {
        let lifter = FakeLifter(demoFaceMask)
        let model = ScanModel(source: DemoFrameSource(), lifter: lifter)
        model.capture()
        model.selectFace(at: CGPoint(x: 0.03, y: 0.03))
        XCTAssertEqual(lifter.taps, [CGPoint(x: 0.03, y: 0.03)])
        guard case .measured(let r) = model.status else { return XCTFail("\(model.status)") }
        XCTAssertEqual(r.width, DemoScene.widthMeters, accuracy: 0.005)
        XCTAssertEqual(r.height, DemoScene.heightMeters, accuracy: 0.005)
    }

    func testTappingAnOutlinedFaceStillUsesTheOutline() {
        let lifter = FakeLifter(demoFaceMask)
        let model = ScanModel(source: DemoFrameSource(), lifter: lifter)
        model.capture()
        let c = DemoScene.portraitCorners
        model.selectFace(at: CGPoint(x: c.map(\.x).reduce(0, +) / 4, y: c.map(\.y).reduce(0, +) / 4))
        XCTAssertEqual(lifter.taps, [], "Vision isn't needed when a rectangle was found")
        guard case .measured = model.status else { return XCTFail("\(model.status)") }
    }

    func testNothingLiftedChangesNothing() {
        let model = ScanModel(source: DemoFrameSource(), lifter: FakeLifter(nil))
        model.capture()
        model.selectFace(at: CGPoint(x: 0.03, y: 0.03))
        XCTAssertEqual(model.status, .chooseFace)
        XCTAssertNil(model.corners)
    }

    func testWithoutALifterAMissedTapChangesNothing() {
        let model = ScanModel(source: DemoFrameSource())
        model.capture()
        model.selectFace(at: CGPoint(x: 0.03, y: 0.03))
        XCTAssertEqual(model.status, .chooseFace)
    }
}
