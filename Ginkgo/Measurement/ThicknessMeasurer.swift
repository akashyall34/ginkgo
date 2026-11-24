import simd

/// A panel's thickness, measured as the height of its top face above the floor it lies on.
struct ThicknessResult: Equatable, Codable {
    /// Meters.
    let thickness: Float
    /// ± in meters: the face's and the floor's depth noise combined.
    let uncertainty: Float
    let facePoints: Int
    let floorPoints: Int
}

enum ThicknessError: Error, Equatable {
    /// Too little of the panel's top face had reliable depth.
    case notEnoughFace(usable: Int, needed: Int)
    /// Too little floor around the panel had reliable depth (the panel fills the view, or it's on a cluttered surface).
    case notEnoughFloor(usable: Int, needed: Int)
    /// The face and the floor aren't parallel: the panel isn't lying flat.
    case notFlat(degrees: Float)
    /// The top face is no higher than the floor: the edge wasn't seen, or this isn't a raised panel.
    case tooThin(meters: Float)
    /// Far thicker than a furniture panel: likely a box or a stack, not one flat panel.
    case tooThick(meters: Float)
    /// The depth is too noisy to give a thickness to within the allowed ±.
    case tooUncertain(meters: Float)

    var explanation: String {
        switch self {
        case .notEnoughFace:
            return "Couldn't see enough of the panel's top. Hold the phone 30 to 50 cm above it, pointing straight down."
        case .notEnoughFloor:
            return "Couldn't see enough floor around the panel. Leave a hand's width of bare floor on every side."
        case .notFlat:
            return "The panel isn't lying flat on the floor. Lay it flat, with nothing underneath it."
        case .tooThin:
            return "Couldn't see the panel's edge above the floor. Lay it on a plain floor in good light and scan again."
        case .tooThick:
            return "That's thicker than one panel. Scan a single panel lying flat."
        case .tooUncertain:
            return "The reading is too unsteady. Hold the phone still, 30 to 50 cm above the panel."
        }
    }
}

/// Measures a flat panel's thickness from one LiDAR depth frame: the top face's plane (inside the outline, edges
/// trimmed) against the floor's plane (a ring just outside the outline, clear of the edge, where depth is unreliable).
/// Thickness is the median distance of the face points from the floor plane.
enum ThicknessMeasurer {
    /// The floor ring starts this far outside the outline (as a share of the outline's size), clear of the edge.
    static let ringInner: Float = 0.15
    /// ...and ends this far outside it.
    static let ringOuter: Float = 0.45
    /// The face and floor must be parallel to within this, or the panel isn't lying flat.
    static let maxTiltDegrees: Float = 3
    /// Thinner than this means the edge wasn't seen; thicker means it isn't one furniture panel.
    static let minThickness: Float = 0.003
    static let maxThickness: Float = 0.08
    /// The thickness must be known to within this, in meters, or it isn't good enough to check sag with.
    static let maxUncertainty: Float = 0.004

    static func measure(corners: [ImagePoint], in s: DepthSnapshot,
                        fitter: RansacPlaneFitter = RansacPlaneFitter(inlierThreshold: 0.006))
        -> Result<ThicknessResult, ThicknessError> {
        guard corners.count == 4 else { return .failure(.notEnoughFace(usable: 0, needed: PlaneMeasurer.minSurfacePoints)) }
        let outline = corners.map { SIMD2($0.u * Float(s.width), $0.v * Float(s.height)) }

        let facePoints = QuadMeasurer.surfacePoints(inside: Polygon.inset(outline, by: QuadMeasurer.edgeInset), in: s)
        guard let face = fit(facePoints, with: fitter) else {
            return .failure(.notEnoughFace(usable: facePoints.count, needed: PlaneMeasurer.minSurfacePoints))
        }

        let floorPoints = ringPoints(around: outline, in: s)
        guard let floor = fit(floorPoints, with: fitter) else {
            return .failure(.notEnoughFloor(usable: floorPoints.count, needed: PlaneMeasurer.minSurfacePoints))
        }

        let tilt = degrees(between: face.plane.normal, and: floor.plane.normal)
        guard tilt <= maxTiltDegrees else { return .failure(.notFlat(degrees: tilt)) }

        let onFace = facePoints.filter { face.plane.distance(to: $0) < fitter.inlierThreshold }
        let thickness = median(onFace.map { floor.plane.distance(to: $0) })
        guard thickness >= minThickness else { return .failure(.tooThin(meters: thickness)) }
        guard thickness <= maxThickness else { return .failure(.tooThick(meters: thickness)) }

        let uncertainty = (face.rms * face.rms + floor.rms * floor.rms).squareRoot()
        guard uncertainty <= maxUncertainty else { return .failure(.tooUncertain(meters: uncertainty)) }
        return .success(ThicknessResult(thickness: thickness, uncertainty: uncertainty,
                                        facePoints: face.inlierCount, floorPoints: floor.inlierCount))
    }

    /// Enough points, mostly on one plane: the same bar the face measurement uses.
    static func fit(_ points: [SIMD3<Float>], with fitter: RansacPlaneFitter) -> RansacPlaneFitter.Fit? {
        guard points.count >= PlaneMeasurer.minSurfacePoints, let fit = fitter.fit(points),
              fit.inlierCount >= PlaneMeasurer.minSurfacePoints,
              Float(fit.inlierCount) >= PlaneMeasurer.minInlierShare * Float(points.count) else { return nil }
        return fit
    }

    /// Reliable depth in the band between the outline grown by `ringInner` and by `ringOuter`.
    static func ringPoints(around outline: [SIMD2<Float>], in s: DepthSnapshot) -> [SIMD3<Float>] {
        let inner = Polygon.inset(outline, by: -ringInner)
        let outer = Polygon.inset(outline, by: -ringOuter)
        let xs = outer.map(\.x), ys = outer.map(\.y)
        guard let loX = xs.min(), let hiX = xs.max(), let loY = ys.min(), let hiY = ys.max() else { return [] }
        let minX = max(0, Int(loX.rounded(.down))), maxX = min(s.width - 1, Int(hiX.rounded(.up)))
        let minY = max(0, Int(loY.rounded(.down))), maxY = min(s.height - 1, Int(hiY.rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return [] }

        var points: [SIMD3<Float>] = []
        for y in minY...maxY {
            for x in minX...maxX {
                let i = y * s.width + x
                let depth = s.depth[i]
                guard s.confidence[i] >= 2, depth.isFinite, depth > 0 else { continue }
                let center = SIMD2(Float(x) + 0.5, Float(y) + 0.5)
                guard Polygon.contains(outer, center), !Polygon.contains(inner, center) else { continue }
                let p = ImagePoint(u: center.x / Float(s.width), v: center.y / Float(s.height))
                points.append(Geometry.unproject(p, depth: depth, intrinsics: s.intrinsics))
            }
        }
        return points
    }

    static func degrees(between a: SIMD3<Float>, and b: SIMD3<Float>) -> Float {
        let cosine = min(1, abs(simd_dot(simd_normalize(a), simd_normalize(b))))
        return acos(cosine) * 180 / .pi
    }

    static func median(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
