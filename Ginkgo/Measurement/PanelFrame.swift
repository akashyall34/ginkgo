import GinkgoCore
import simd

/// Where a panel lies in the AR world, from three corners the person taps: bottom-left, bottom-right, top-left.
/// Turns the cutting diagram's "x mm from the left edge, y mm from the bottom edge" into a point on the real panel.
struct PanelFrame: Equatable {
    /// The bottom-left corner, meters, world space.
    let origin: SIMD3<Float>
    /// Unit vectors along the panel's bottom edge (left to right) and its left edge (bottom to top).
    let xAxis: SIMD3<Float>
    let yAxis: SIMD3<Float>
    /// The panel's size as tapped, meters.
    let width: Float
    let height: Float

    enum Problem: Error, Equatable {
        /// Two taps landed on the same spot.
        case cornersTooClose
        /// The tapped width or height is off from the scanned size by more than the tolerance.
        case widthMismatch(tappedMm: Float, expectedMm: Float)
        case heightMismatch(tappedMm: Float, expectedMm: Float)
        /// The corners don't make a square angle: one tap is on the wrong corner.
        case notSquare(degrees: Float)

        var explanation: String {
            switch self {
            case .cornersTooClose:
                return "Two taps landed in the same place. Tap the bottom-left, bottom-right and top-left corners."
            case let .widthMismatch(tapped, expected):
                return String(format: "The taps give a %.0f mm bottom edge, but the panel was scanned at %.0f mm. "
                              + "Tap the corners again, right on the panel's edges.", tapped, expected)
            case let .heightMismatch(tapped, expected):
                return String(format: "The taps give a %.0f mm left edge, but the panel was scanned at %.0f mm. "
                              + "Tap the corners again, right on the panel's edges.", tapped, expected)
            case .notSquare:
                return "Those corners aren't square. Tap the bottom-left, then the bottom-right, then the top-left corner."
            }
        }
    }

    /// How far the tapped size may be from the scanned size before the lines would land in the wrong place, meters.
    static let sizeTolerance: Float = 0.005
    /// How far from 90° the tapped corner may be.
    static let squareTolerance: Float = 3

    static func from(bottomLeft: SIMD3<Float>, bottomRight: SIMD3<Float>, topLeft: SIMD3<Float>,
                     expectedWidthMm: Double, expectedHeightMm: Double) -> Result<PanelFrame, Problem> {
        let along = bottomRight - bottomLeft, up = topLeft - bottomLeft
        let width = simd_length(along), height = simd_length(up)
        guard width > 0.01, height > 0.01 else { return .failure(.cornersTooClose) }

        let angle = acos(max(-1, min(1, simd_dot(along / width, up / height)))) * 180 / .pi
        guard abs(angle - 90) <= squareTolerance else { return .failure(.notSquare(degrees: angle)) }

        let expectedWidth = Float(expectedWidthMm) / 1000, expectedHeight = Float(expectedHeightMm) / 1000
        guard abs(width - expectedWidth) <= sizeTolerance else {
            return .failure(.widthMismatch(tappedMm: width * 1000, expectedMm: expectedWidth * 1000))
        }
        guard abs(height - expectedHeight) <= sizeTolerance else {
            return .failure(.heightMismatch(tappedMm: height * 1000, expectedMm: expectedHeight * 1000))
        }

        // Square up the left edge against the bottom edge, so lines are drawn exactly perpendicular.
        let xAxis = along / width
        let yAxis = simd_normalize(up - simd_dot(up, xAxis) * xAxis)
        return .success(PanelFrame(origin: bottomLeft, xAxis: xAxis, yAxis: yAxis, width: width, height: height))
    }

    /// The point on the panel `xMm` from its left edge and `yMm` from its bottom edge, world space.
    func point(xMm: Double, yMm: Double) -> SIMD3<Float> {
        origin + xAxis * Float(xMm / 1000) + yAxis * Float(yMm / 1000)
    }

    /// A cut line's two ends, world space.
    func ends(of line: CutLineEnds) -> (SIMD3<Float>, SIMD3<Float>) {
        (point(xMm: line.start.x, yMm: line.start.y), point(xMm: line.end.x, yMm: line.end.y))
    }
}

/// A cut line's ends in panel mm (x from the left edge, y from the bottom edge).
struct CutLineEnds: Equatable {
    let start: SIMD2<Double>
    let end: SIMD2<Double>
}

extension CutLineEnds {
    /// A vertical line runs up the panel at its distance from the left edge; a horizontal one across, at its
    /// distance from the bottom edge.
    init(_ line: CutLine) {
        switch line.direction {
        case .vertical:
            self.init(start: SIMD2(line.positionMm, line.fromMm), end: SIMD2(line.positionMm, line.toMm))
        case .horizontal:
            self.init(start: SIMD2(line.fromMm, line.positionMm), end: SIMD2(line.toMm, line.positionMm))
        }
    }
}
