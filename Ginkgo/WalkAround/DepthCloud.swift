import simd

/// Raw LiDAR depth from many frames, merged into one room-space point set while the person walks.
/// The same depth and confidence that make the still-frame scan accurate to millimeters, instead of
/// ARKit's coarse, smoothed room mesh. Points are averaged into small cells so memory stays bounded.
struct DepthCloud {
    /// Cell size: fine enough for millimeter fits, coarse enough to merge repeated views.
    static let cell: Float = 0.005
    /// LiDAR is most accurate up close; farther readings are noisier and left out.
    static let maxRange: Float = 2.5
    /// Every second pixel in each direction: plenty of points, a quarter of the work.
    static let pixelStep = 2

    private struct Sum {
        var total: SIMD3<Float>
        var count: Float
    }

    private var sums: [SIMD3<Int32>: Sum] = [:]

    var count: Int { sums.count }

    /// One averaged point per occupied cell.
    var points: [SIMD3<Float>] { sums.values.map { $0.total / $0.count } }

    /// Adds a frame's high-confidence depth, placed in the room by the camera's pose.
    mutating func add(_ frame: DepthSnapshot, cameraToWorld: simd_float4x4) {
        for row in stride(from: 0, to: frame.height, by: Self.pixelStep) {
            for column in stride(from: 0, to: frame.width, by: Self.pixelStep) {
                let index = row * frame.width + column
                let depth = frame.depth[index]
                guard frame.confidence[index] == 2, depth.isFinite, depth > 0.05, depth <= Self.maxRange else { continue }
                let pixel = ImagePoint(u: (Float(column) + 0.5) / Float(frame.width), v: (Float(row) + 0.5) / Float(frame.height))
                let camera = Geometry.unproject(pixel, depth: depth, intrinsics: frame.intrinsics)
                let world = cameraToWorld * SIMD4(camera, 1)
                let point = SIMD3(world.x, world.y, world.z)
                let key = SIMD3<Int32>((point / Self.cell).rounded(.down))
                sums[key, default: Sum(total: .zero, count: 0)].total += point
                sums[key, default: Sum(total: .zero, count: 0)].count += 1
            }
        }
    }
}

extension BoxFit {
    /// Re-fits a coarse box (from the room mesh) on precise depth points. The mesh box says which object
    /// was aimed at and roughly where; only depth points inside it, plus `margin`, are measured, and the
    /// floor is taken from depth points on the floor just around the piece.
    static func refine(_ coarse: FittedBox, cloud: [SIMD3<Float>], margin: Float = 0.05) -> FittedBox? {
        let (cosA, sinA) = (cos(coarse.yaw), sin(coarse.yaw))
        func local(_ p: SIMD3<Float>) -> SIMD2<Float> {
            let dx = p.x - coarse.baseCenter.x, dz = p.z - coarse.baseCenter.z
            return SIMD2(dx * cosA + dz * sinA, -dx * sinA + dz * cosA)
        }
        let halfLength = coarse.length / 2, halfWidth = coarse.width / 2
        func within(_ q: SIMD2<Float>, _ extra: Float) -> Bool {
            abs(q.x) <= halfLength + extra && abs(q.y) <= halfWidth + extra
        }

        // Floor: depth points in a ring just outside the footprint, near the mesh's floor height.
        let ring = cloud.filter {
            abs($0.y - coarse.baseCenter.y) < 0.05 && within(local($0), 0.30) && !within(local($0), margin)
        }
        let floorY = ring.count >= 50 ? percentile(ring.map(\.y), 0.5) : coarse.baseCenter.y

        let top = floorY + coarse.height + margin
        let inside = cloud.filter { $0.y > floorY + 0.01 && $0.y < top && within(local($0), margin) }
        return try? fit(inside, floorY: floorY)
    }
}
