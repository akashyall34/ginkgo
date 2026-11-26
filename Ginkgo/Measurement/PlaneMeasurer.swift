import Foundation
import simd

/// The distance between two tapped points on one frozen frame.
struct DistanceResult: Equatable {
    let meters: Float
    /// ± from plane noise and viewing angle, in meters.
    let uncertainty: Float
    /// Depth points on the fitted plane.
    let surfacePoints: Int
    /// Root-mean-square distance of those points from the plane, in meters.
    let fitNoise: Float
    /// How edge-on the surface is seen: 0° is straight on.
    let viewAngleDegrees: Float

    var centimeters: Float { meters * 100 }
    var uncertaintyCentimeters: Float { uncertainty * 100 }
}

enum PlaneMeasureError: Error, Equatable {
    case samePoint
    /// A face is measured from exactly four corners.
    case needsFourCorners
    case outsideImage
    /// Too few reliable depth points on the surface between the two taps.
    case notEnoughSurface(usable: Int, needed: Int)
    /// No single flat surface covers enough of those points.
    case noFlatSurface
    /// A tap's line of sight runs along the surface or misses it.
    case missesSurface(point: Int)
    /// The surface is seen too close to edge-on to measure along it reliably.
    case tooShallow(degrees: Float)
    /// The result would be less certain than the limit; shows the ± it would have had.
    case tooUncertain(meters: Float)
}

/// Measures between two taps by fitting a plane to the reliable depth on the
/// surface between them, then casting each tap's line of sight onto that plane.
/// The taps themselves don't need good depth, so edges measure cleanly.
enum PlaneMeasurer {
    static let minSurfacePoints = 30
    /// Readings less certain than this are refused, in meters.
    static let maxUncertainty: Float = 0.01
    /// Readings where a tap sees the surface more edge-on than this are refused.
    static let maxViewAngleDegrees: Float = 70
    /// At least this share of the sampled points must lie on the fitted plane.
    static let minInlierShare: Float = 0.6
    /// Half-width of the strip of depth pixels sampled along the line between taps.
    static let stripHalfWidth: Float = 6

    static func distance(from a: ImagePoint, to b: ImagePoint, in s: DepthSnapshot,
                         fitter: RansacPlaneFitter = RansacPlaneFitter())
        -> Result<DistanceResult, PlaneMeasureError> {
        guard a != b else { return .failure(.samePoint) }
        guard a.isInside, b.isInside else { return .failure(.outsideImage) }

        let points = surfacePoints(between: a, and: b, in: s)
        guard points.count >= minSurfacePoints else {
            return .failure(.notEnoughSurface(usable: points.count, needed: minSurfacePoints))
        }
        guard let fit = fitter.fit(points), fit.inlierCount >= minSurfacePoints,
              Float(fit.inlierCount) >= minInlierShare * Float(points.count) else {
            return .failure(.noFlatSurface)
        }

        let ra = Geometry.unproject(a, depth: 1, intrinsics: s.intrinsics)
        let rb = Geometry.unproject(b, depth: 1, intrinsics: s.intrinsics)
        guard let ta = fit.plane.hit(direction: ra) else { return .failure(.missesSurface(point: 1)) }
        guard let tb = fit.plane.hit(direction: rb) else { return .failure(.missesSurface(point: 2)) }
        let pa = ra * ta
        let pb = rb * tb

        let cosA = abs(simd_dot(fit.plane.normal, simd_normalize(ra)))
        let cosB = abs(simd_dot(fit.plane.normal, simd_normalize(rb)))
        switch assess(noise: fit.rms, cosA: cosA, cosB: cosB) {
        case .failure(let e):
            return .failure(e)
        case .success(let q):
            return .success(DistanceResult(meters: simd_distance(pa, pb), uncertainty: q.uncertainty,
                                           surfacePoints: fit.inlierCount, fitNoise: fit.rms,
                                           viewAngleDegrees: q.angleDegrees))
        }
    }

    /// Judges whether a reading is trustworthy. `cosA`/`cosB` are how directly each
    /// tap's line of sight faces the surface (1 = straight on, 0 = edge-on).
    static func assess(noise: Float, cosA: Float, cosB: Float)
        -> Result<(uncertainty: Float, angleDegrees: Float), PlaneMeasureError> {
        let angle = acos(min(1, min(cosA, cosB))) * 180 / .pi
        guard angle <= maxViewAngleDegrees else { return .failure(.tooShallow(degrees: angle)) }
        // Surface noise moves each end along its line of sight by about noise / cos.
        let ea = noise / cosA, eb = noise / cosB
        let uncertainty = (ea * ea + eb * eb).squareRoot()
        guard uncertainty <= maxUncertainty else { return .failure(.tooUncertain(meters: uncertainty)) }
        return .success((uncertainty, angle))
    }

    /// High-confidence 3D points in a strip of the depth map running between the taps.
    static func surfacePoints(between a: ImagePoint, and b: ImagePoint, in s: DepthSnapshot) -> [SIMD3<Float>] {
        let ax = a.u * Float(s.width), ay = a.v * Float(s.height)
        let bx = b.u * Float(s.width), by = b.v * Float(s.height)
        let dx = bx - ax, dy = by - ay
        let len2 = dx * dx + dy * dy

        let minX = max(0, Int((min(ax, bx) - stripHalfWidth).rounded(.down)))
        let maxX = min(s.width - 1, Int((max(ax, bx) + stripHalfWidth).rounded(.up)))
        let minY = max(0, Int((min(ay, by) - stripHalfWidth).rounded(.down)))
        let maxY = min(s.height - 1, Int((max(ay, by) + stripHalfWidth).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return [] }

        var points: [SIMD3<Float>] = []
        for y in minY...maxY {
            for x in minX...maxX {
                let i = y * s.width + x
                let d = s.depth[i]
                guard s.confidence[i] >= 2, d.isFinite, d > 0 else { continue }
                // Distance from the pixel center to the segment a–b.
                let px = Float(x) + 0.5, py = Float(y) + 0.5
                let t = len2 > 0 ? max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) : 0
                let cx = ax + t * dx - px, cy = ay + t * dy - py
                guard cx * cx + cy * cy <= stripHalfWidth * stripHalfWidth else { continue }
                let p = ImagePoint(u: px / Float(s.width), v: py / Float(s.height))
                points.append(Geometry.unproject(p, depth: d, intrinsics: s.intrinsics))
            }
        }
        return points
    }
}

extension PlaneMeasureError {
    /// What went wrong, in plain words, with what to do about it.
    var explanation: String {
        switch self {
        case .samePoint:
            return "Those are the same point. Tap two different points."
        case .needsFourCorners:
            return "A face needs four corners."
        case .outsideImage:
            return "A point is outside the photo."
        case .notEnoughSurface(let usable, let needed):
            return "Only \(usable) reliable depth points between your taps, needs \(needed). "
                + "Move closer or measure across a matte surface."
        case .noFlatSurface:
            return "No flat surface between your taps. Measure along one flat face."
        case .missesSurface(let point):
            return "Point \(point) doesn't land on the surface. Capture from more straight on."
        case .tooShallow(let degrees):
            return String(format: "The surface is seen too edge-on (%.0f°). Capture from more straight on.", degrees)
        case .tooUncertain(let meters):
            return String(format: "Too uncertain (± %.1f cm). ", meters * 100)
                + "Capture from more straight on, and keep both taps on one flat face."
        }
    }
}
