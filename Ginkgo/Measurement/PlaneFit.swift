import simd

/// A plane: all points x with normal·x + offset = 0. The normal has length 1.
struct Plane: Equatable {
    let normal: SIMD3<Float>
    let offset: Float

    func distance(to p: SIMD3<Float>) -> Float { abs(simd_dot(normal, p) + offset) }

    /// Where a ray from the camera origin along `direction` meets the plane, as the
    /// multiple of `direction`. Nil if the ray runs parallel to the plane or the
    /// plane is behind the camera.
    func hit(direction: SIMD3<Float>) -> Float? {
        let denom = simd_dot(normal, direction)
        guard abs(denom) > 1e-6 else { return nil }
        let t = -offset / denom
        return t > 0 ? t : nil
    }

    /// The plane through three points, or nil if they are (nearly) on one line.
    static func through(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Plane? {
        let n = simd_cross(b - a, c - a)
        let len = simd_length(n)
        guard len > 1e-9 else { return nil }
        let unit = n / len
        return Plane(normal: unit, offset: -simd_dot(unit, a))
    }

    /// Least-squares plane: through the centroid, normal along the direction of
    /// least spread (the smallest eigenvector of the covariance).
    static func leastSquares(_ points: [SIMD3<Float>]) -> Plane? {
        guard points.count >= 3 else { return nil }
        let centroid = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
        var cov = simd_float3x3(0)
        for p in points {
            let d = p - centroid
            cov += simd_float3x3(columns: (d * d.x, d * d.y, d * d.z))
        }
        let normal = SymmetricEigen.smallestEigenvector(cov)
        guard simd_length(normal) > 0.5 else { return nil }
        return Plane(normal: normal, offset: -simd_dot(normal, centroid))
    }
}

enum SymmetricEigen {
    /// The unit eigenvector of a symmetric 3×3 matrix with the smallest eigenvalue,
    /// found with the Jacobi rotation method.
    static func smallestEigenvector(_ m: simd_float3x3) -> SIMD3<Float> {
        var a = [[Float]](repeating: [0, 0, 0], count: 3)
        for i in 0..<3 { for j in 0..<3 { a[i][j] = m[j][i] } }
        var v: [[Float]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

        for _ in 0..<50 {
            // Largest off-diagonal element.
            var p = 0, q = 1
            if abs(a[0][2]) > abs(a[p][q]) { p = 0; q = 2 }
            if abs(a[1][2]) > abs(a[p][q]) { p = 1; q = 2 }
            if abs(a[p][q]) < 1e-12 { break }

            let theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
            let t = (theta >= 0 ? 1 : -1) / (abs(theta) + (theta * theta + 1).squareRoot())
            let c = 1 / (t * t + 1).squareRoot()
            let s = t * c

            for k in 0..<3 {
                let akp = a[k][p], akq = a[k][q]
                a[k][p] = c * akp - s * akq
                a[k][q] = s * akp + c * akq
            }
            for k in 0..<3 {
                let apk = a[p][k], aqk = a[q][k]
                a[p][k] = c * apk - s * aqk
                a[q][k] = s * apk + c * aqk
            }
            for k in 0..<3 {
                let vkp = v[k][p], vkq = v[k][q]
                v[k][p] = c * vkp - s * vkq
                v[k][q] = s * vkp + c * vkq
            }
        }

        // The smallest of the three diagonal entries; the range is never empty.
        let i = (0..<3).min { a[$0][$0] < a[$1][$1] } ?? 0
        return simd_normalize(SIMD3(v[0][i], v[1][i], v[2][i]))
    }
}

/// Finds the dominant plane in noisy points that may include other surfaces.
struct RansacPlaneFitter {
    /// Points closer than this to the plane count as on it, in meters.
    var inlierThreshold: Float = 0.01
    var iterations = 200
    var seed: UInt64 = 1

    struct Fit {
        let plane: Plane
        let inlierCount: Int
        /// Root-mean-square distance of inliers from the plane, in meters.
        let rms: Float
    }

    func fit(_ points: [SIMD3<Float>]) -> Fit? {
        guard points.count >= 3 else { return nil }
        var rng = SplitMix(seed: seed)
        var best: [SIMD3<Float>] = []

        for _ in 0..<iterations {
            let a = points[rng.next(below: points.count)]
            let b = points[rng.next(below: points.count)]
            let c = points[rng.next(below: points.count)]
            guard let candidate = Plane.through(a, b, c) else { continue }
            let inliers = points.filter { candidate.distance(to: $0) < inlierThreshold }
            if inliers.count > best.count { best = inliers }
        }
        guard best.count >= 3, let refined = Plane.leastSquares(best) else { return nil }

        // Re-collect inliers against the refined plane.
        let final = points.filter { refined.distance(to: $0) < inlierThreshold }
        guard final.count >= 3 else { return nil }
        let sumSquares = final.reduce(Float(0)) { sum, p in
            let d = refined.distance(to: p)
            return sum + d * d
        }
        let rms = (sumSquares / Float(final.count)).squareRoot()
        return Fit(plane: refined, inlierCount: final.count, rms: rms)
    }
}

/// Small deterministic random generator, so measurements repeat exactly.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below n: Int) -> Int { Int(next() % UInt64(n)) }
}
