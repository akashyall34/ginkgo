import simd

/// Width and height of a rectangular face found from its four corners.
struct QuadResult: Equatable, Codable {
    /// Average of the top and bottom edges, in meters.
    let width: Float
    /// Average of the left and right edges, in meters.
    let height: Float
    /// ± for each side: plane noise combined with how much opposite edges disagree.
    let uncertainty: Float
    let surfacePoints: Int
    let viewAngleDegrees: Float
    /// How much the top and bottom edges disagree, in meters.
    let widthEdgeGap: Float
    /// How much the left and right edges disagree, in meters.
    let heightEdgeGap: Float
}

extension QuadResult {
    /// Opposite edges of a real rectangle are equal; a gap bigger than this almost
    /// always means a corner sits in the wrong place (a hand covering it, a shadow).
    static let misplacedCornerGap: Float = 0.01

    /// What to check when the edges disagree, or nil when they agree.
    var misplacedCornerHint: String? {
        let (edges, gap) = widthEdgeGap >= heightEdgeGap ? ("top and bottom", widthEdgeGap) : ("left and right", heightEdgeGap)
        guard gap > Self.misplacedCornerGap else { return nil }
        return String(format: "The %@ edges differ by %.1f cm. A corner is probably off: ", edges, gap * 100)
            + "drag the corners onto the face's corners."
    }
}

enum Polygon {
    /// Whether a point lies inside (or on the edge of) a convex polygon, in either winding.
    static func contains(_ poly: [SIMD2<Float>], _ p: SIMD2<Float>) -> Bool {
        guard poly.count >= 3 else { return false }
        var sign: Float = 0
        for i in 0..<poly.count {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            if cross != 0 {
                if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false }
            }
        }
        return true
    }

    /// The polygon shrunk toward its center by `fraction` (0.15 keeps the inner 85%).
    static func inset(_ poly: [SIMD2<Float>], by fraction: Float) -> [SIMD2<Float>] {
        let center = poly.reduce(SIMD2<Float>(repeating: 0), +) / Float(poly.count)
        return poly.map { center + ($0 - center) * (1 - fraction) }
    }
}

enum QuadMeasurer {
    /// Share of the face trimmed off its border before sampling depth, to stay
    /// clear of the unreliable edges.
    static let edgeInset: Float = 0.15

    /// Measures a rectangular face. `corners` are top-left, top-right,
    /// bottom-right, bottom-left, in raw image coordinates.
    static func measure(corners: [ImagePoint], in s: DepthSnapshot,
                        fitter: RansacPlaneFitter = RansacPlaneFitter())
        -> Result<QuadResult, PlaneMeasureError> {
        guard corners.count == 4 else { return .failure(.needsFourCorners) }
        guard corners.allSatisfy(\.isInside) else { return .failure(.outsideImage) }

        let poly = Polygon.inset(corners.map { SIMD2($0.u * Float(s.width), $0.v * Float(s.height)) },
                                 by: edgeInset)
        let points = surfacePoints(inside: poly, in: s)
        guard points.count >= PlaneMeasurer.minSurfacePoints else {
            return .failure(.notEnoughSurface(usable: points.count, needed: PlaneMeasurer.minSurfacePoints))
        }
        guard let fit = fitter.fit(points),
              Float(fit.inlierCount) >= PlaneMeasurer.minInlierShare * Float(points.count) else {
            return .failure(.noFlatSurface)
        }

        var corners3D: [SIMD3<Float>] = []
        // The worst-case corner (the most edge-on one) sets the angle and noise check.
        var worst: Float = 1
        for (i, c) in corners.enumerated() {
            let ray = Geometry.unproject(c, depth: 1, intrinsics: s.intrinsics)
            guard let t = fit.plane.hit(direction: ray) else { return .failure(.missesSurface(point: i + 1)) }
            corners3D.append(ray * t)
            worst = min(worst, abs(simd_dot(fit.plane.normal, simd_normalize(ray))))
        }
        let planePart: Float
        let angle: Float
        switch PlaneMeasurer.assess(noise: fit.rms, cosA: worst, cosB: worst) {
        case .failure(let e): return .failure(e)
        case .success(let q): planePart = q.uncertainty; angle = q.angleDegrees
        }

        let top = simd_distance(corners3D[0], corners3D[1])
        let bottom = simd_distance(corners3D[3], corners3D[2])
        let left = simd_distance(corners3D[0], corners3D[3])
        let right = simd_distance(corners3D[1], corners3D[2])

        // Opposite sides of a real rectangle are equal; any mismatch is error.
        let mismatch = max(abs(top - bottom), abs(left - right)) / 2
        let uncertainty = (planePart * planePart + mismatch * mismatch).squareRoot()
        guard uncertainty <= PlaneMeasurer.maxUncertainty else {
            return .failure(.tooUncertain(meters: uncertainty))
        }
        return .success(QuadResult(width: (top + bottom) / 2, height: (left + right) / 2,
                                   uncertainty: uncertainty, surfacePoints: fit.inlierCount,
                                   viewAngleDegrees: angle,
                                   widthEdgeGap: abs(top - bottom), heightEdgeGap: abs(left - right)))
    }

    static func surfacePoints(inside poly: [SIMD2<Float>], in s: DepthSnapshot) -> [SIMD3<Float>] {
        let xs = poly.map(\.x), ys = poly.map(\.y)
        guard let loX = xs.min(), let hiX = xs.max(), let loY = ys.min(), let hiY = ys.max() else { return [] }
        let minX = max(0, Int(loX.rounded(.down))), maxX = min(s.width - 1, Int(hiX.rounded(.up)))
        let minY = max(0, Int(loY.rounded(.down))), maxY = min(s.height - 1, Int(hiY.rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return [] }

        var points: [SIMD3<Float>] = []
        for y in minY...maxY {
            for x in minX...maxX {
                let i = y * s.width + x
                let d = s.depth[i]
                guard s.confidence[i] >= 2, d.isFinite, d > 0 else { continue }
                let center = SIMD2(Float(x) + 0.5, Float(y) + 0.5)
                guard Polygon.contains(poly, center) else { continue }
                let p = ImagePoint(u: center.x / Float(s.width), v: center.y / Float(s.height))
                points.append(Geometry.unproject(p, depth: d, intrinsics: s.intrinsics))
            }
        }
        return points
    }
}
