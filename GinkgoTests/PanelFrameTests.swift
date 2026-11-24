import GinkgoCore
import simd
import XCTest
@testable import Ginkgo

/// From three tapped corners to points on the real panel, and every way the taps can be wrong refused.
final class PanelFrameTests: XCTestCase {
    /// A 460 × 400 mm panel on the floor (y up in AR), its bottom edge along +x, its left edge along -z.
    private let bottomLeft = SIMD3<Float>(0.10, 0, -0.30)
    private var bottomRight: SIMD3<Float> { bottomLeft + SIMD3(0.46, 0, 0) }
    private var topLeft: SIMD3<Float> { bottomLeft + SIMD3(0, 0, -0.40) }

    private func frame(bottomRight: SIMD3<Float>? = nil, topLeft: SIMD3<Float>? = nil) -> Result<PanelFrame, PanelFrame.Problem> {
        PanelFrame.from(bottomLeft: bottomLeft, bottomRight: bottomRight ?? self.bottomRight, topLeft: topLeft ?? self.topLeft,
                        expectedWidthMm: 460, expectedHeightMm: 400)
    }

    private func assertClose(_ a: SIMD3<Float>, _ b: SIMD3<Float>, line: UInt = #line) {
        XCTAssertLessThan(simd_distance(a, b), 0.0001, "\(a) vs \(b)", line: line)
    }

    // MARK: - Known answers

    func testTheCornersComeBackAsTheCorners() throws {
        let panel = try frame().get()
        assertClose(panel.point(xMm: 0, yMm: 0), bottomLeft)
        assertClose(panel.point(xMm: 460, yMm: 0), bottomRight)
        assertClose(panel.point(xMm: 0, yMm: 400), topLeft)
        assertClose(panel.point(xMm: 460, yMm: 400), bottomLeft + SIMD3(0.46, 0, -0.40))
    }

    func testTheSeatsLeftLineLandsFourMillimetresIn() throws {
        // The sample seat's left line: 4 mm from the left edge, from 34 to 334 mm up.
        let line = CutLine(direction: .vertical, positionMm: 4, fromMm: 34, toMm: 334, piece: "seat")
        let (start, end) = try frame().get().ends(of: CutLineEnds(line))
        assertClose(start, bottomLeft + SIMD3(0.004, 0, -0.034))
        assertClose(end, bottomLeft + SIMD3(0.004, 0, -0.334))
    }

    func testHorizontalLinesRunAcross() {
        let line = CutLine(direction: .horizontal, positionMm: 34, fromMm: 4, toMm: 404, piece: "seat")
        XCTAssertEqual(CutLineEnds(line), CutLineEnds(start: SIMD2(4, 34), end: SIMD2(404, 34)))
    }

    func testTapsWithinTheToleranceAreSquaredUp() throws {
        // The top-left tap is 1.5° off square and 2 mm long: accepted, and the left edge is made exactly perpendicular.
        let skewed = bottomLeft + SIMD3(0.0105, 0, -0.402)
        let panel = try frame(topLeft: skewed).get()
        XCTAssertEqual(simd_dot(panel.xAxis, panel.yAxis), 0, accuracy: 0.0001)
        XCTAssertEqual(simd_length(panel.yAxis), 1, accuracy: 0.0001)
    }

    // MARK: - Boundaries

    func testExactlyAtTheSizeToleranceIsAccepted() {
        guard case .success = frame(bottomRight: bottomLeft + SIMD3(0.46 + PanelFrame.sizeTolerance * 0.99, 0, 0)) else {
            return XCTFail("Just inside the tolerance must pass")
        }
    }

    func testJustPastTheSizeToleranceIsRefused() {
        guard case .failure(.widthMismatch) = frame(bottomRight: bottomLeft + SIMD3(0.466, 0, 0)) else {
            return XCTFail("6 mm off must be refused")
        }
    }

    // MARK: - Refusals

    func testAWrongHeightIsRefused() {
        guard case .failure(.heightMismatch(let tapped, let expected)) = frame(topLeft: bottomLeft + SIMD3(0, 0, -0.38)) else {
            return XCTFail("A 380 mm left edge on a 400 mm panel")
        }
        XCTAssertEqual(tapped, 380, accuracy: 0.5)
        XCTAssertEqual(expected, 400, accuracy: 0.01)
    }

    func testCornersThatArentSquareAreRefused() {
        // The "top-left" tap is really near the top-right corner.
        guard case .failure(.notSquare) = frame(topLeft: bottomLeft + SIMD3(0.30, 0, -0.30)) else {
            return XCTFail("A tap on the wrong corner")
        }
    }

    func testTwoTapsOnOneSpotAreRefused() {
        guard case .failure(.cornersTooClose) = frame(bottomRight: bottomLeft) else { return XCTFail("Same spot twice") }
    }

    func testEveryProblemSaysWhatToDo() {
        let problems: [PanelFrame.Problem] = [.cornersTooClose, .widthMismatch(tappedMm: 470, expectedMm: 460),
                                              .heightMismatch(tappedMm: 390, expectedMm: 400), .notSquare(degrees: 60)]
        let texts = problems.map(\.explanation)
        XCTAssertFalse(texts.contains(where: \.isEmpty))
        XCTAssertEqual(Set(texts).count, texts.count)
        XCTAssertTrue(texts[1].contains("470 mm") && texts[1].contains("460 mm"), texts[1])
    }
}
