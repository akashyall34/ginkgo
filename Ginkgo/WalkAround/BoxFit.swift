import Foundation
import simd

/// An upright box around a piece of furniture, in meters, in ARKit world space (y is up).
struct FittedBox: Equatable {
    /// The longer side across the floor.
    let length: Float
    /// The shorter side across the floor.
    let width: Float
    /// From the floor to the top.
    let height: Float
    /// Center of the box's footprint on the floor.
    let baseCenter: SIMD3<Float>
    /// Rotation of the length side around the vertical axis, in radians, 0..<π.
    let yaw: Float
    /// Typical distance of the surface points from the box's faces: the ± of each size.
    let uncertainty: Float
    let pointCount: Int
}

enum BoxFitError: Error, Equatable {
    case tooFewPoints(Int)

    var explanation: String {
        switch self {
        case .tooFewPoints:
            return "Not enough of the furniture was scanned. Walk slowly around it with the phone pointed at it."
        }
    }
}

enum BoxFit {
    static let minimumPoints = 200
    /// Share of points ignored at each end of every side, so stray mesh bits don't grow the box.
    static let trim: Float = 0.02
    /// Points used for the rotation search; enough for millimeter results, quick on a phone.
    static let searchSample = 4000

    /// Fits the smallest upright box (by footprint area) around the points, standing on the floor.
    static func fit(_ points: [SIMD3<Float>], floorY: Float) throws(BoxFitError) -> FittedBox {
        guard points.count >= minimumPoints else { throw BoxFitError.tooFewPoints(points.count) }
        let stride = max(1, points.count / searchSample)
        let sample = Swift.stride(from: 0, to: points.count, by: stride).map { SIMD2(points[$0].x, points[$0].z) }

        // Coarse search over a quarter turn (a rectangle repeats every 90°), then refine.
        var best = (angle: Float(0), area: Float.infinity)
        for step in 0..<180 {
            let angle = Float(step) * .pi / 360
            let area = footprint(sample, angle: angle).area
            if area < best.area { best = (angle, area) }
        }
        for step in -10...10 {
            let angle = best.angle + Float(step) * .pi / 3600
            let area = footprint(sample, angle: angle).area
            if area < best.area { best = (angle, area) }
        }

        let all = points.map { SIMD2($0.x, $0.z) }
        let box = refined(footprint(all, angle: best.angle), points: all, angle: best.angle)
        let height = topHeight(of: points.map(\.y)) - floorY
        let (cosA, sinA) = (cos(best.angle), sin(best.angle))
        // Back from the rotated frame to world x/z.
        let centerX = box.midU * cosA - box.midV * sinA
        let centerZ = box.midU * sinA + box.midV * cosA

        let longIsU = box.sizeU >= box.sizeV
        let yaw = normalizedYaw(longIsU ? best.angle : best.angle + .pi / 2)

        let fitted = FittedBox(length: max(box.sizeU, box.sizeV), width: min(box.sizeU, box.sizeV), height: height,
                               baseCenter: SIMD3(centerX, floorY, centerZ), yaw: yaw, uncertainty: 0, pointCount: points.count)
        return FittedBox(length: fitted.length, width: fitted.width, height: fitted.height, baseCenter: fitted.baseCenter,
                         yaw: fitted.yaw, uncertainty: residual(points, box: fitted), pointCount: points.count)
    }

    /// Where the top face is: the median of the heights within `faceBand` of the near-top height, so a few stray
    /// points above the furniture don't raise it. The near-top height is one of the heights, so the band is never empty.
    static func topHeight(of heights: [Float]) -> Float {
        let roughTop = percentile(heights, 1 - trim)
        return percentile(heights.filter { abs($0 - roughTop) <= faceBand }, 0.5)
    }

    /// The box's turn as an angle from 0 up to a half turn (a box looks the same turned 180°).
    static func normalizedYaw(_ angle: Float) -> Float {
        let yaw = angle.truncatingRemainder(dividingBy: .pi)
        return yaw < 0 ? yaw + .pi : yaw
    }

    /// Where a side really is: the median of the points within `faceBand` of the rough edge, or the edge itself.
    static func settledFace(_ values: [Float], at edge: Float) -> Float {
        let near = values.filter { abs($0 - edge) <= faceBand }
        return near.isEmpty ? edge : percentile(near, 0.5)
    }

    private struct Footprint {
        let minU: Float, maxU: Float, minV: Float, maxV: Float
        var sizeU: Float { maxU - minU }
        var sizeV: Float { maxV - minV }
        var midU: Float { (minU + maxU) / 2 }
        var midV: Float { (minV + maxV) / 2 }
        var area: Float { sizeU * sizeV }
    }

    /// How far from a rough face position its points are looked for when settling the face.
    static let faceBand: Float = 0.02

    /// Moves each side onto the median of the points lying on it. Trimmed extents sit on the
    /// outermost noise; the median sits on the surface itself.
    private static func refined(_ rough: Footprint, points: [SIMD2<Float>], angle: Float) -> Footprint {
        let (cosA, sinA) = (cos(angle), sin(angle))
        let u = points.map { $0.x * cosA + $0.y * sinA }
        let v = points.map { -$0.x * sinA + $0.y * cosA }
        return Footprint(minU: settledFace(u, at: rough.minU), maxU: settledFace(u, at: rough.maxU),
                         minV: settledFace(v, at: rough.minV), maxV: settledFace(v, at: rough.maxV))
    }

    /// Trimmed extents of the points in a frame rotated by `angle`.
    private static func footprint(_ points: [SIMD2<Float>], angle: Float) -> Footprint {
        let (cosA, sinA) = (cos(angle), sin(angle))
        let u = points.map { $0.x * cosA + $0.y * sinA }
        let v = points.map { -$0.x * sinA + $0.y * cosA }
        return Footprint(minU: percentile(u, trim), maxU: percentile(u, 1 - trim),
                         minV: percentile(v, trim), maxV: percentile(v, 1 - trim))
    }

    /// Root-mean-square distance from each point to the nearest side or top face of the box.
    private static func residual(_ points: [SIMD3<Float>], box: FittedBox) -> Float {
        let (cosA, sinA) = (cos(box.yaw), sin(box.yaw))
        var sum: Float = 0
        for p in points {
            let dx = p.x - box.baseCenter.x, dz = p.z - box.baseCenter.z
            let u = abs(dx * cosA + dz * sinA), v = abs(-dx * sinA + dz * cosA)
            let distance = min(abs(u - box.length / 2), abs(v - box.width / 2), abs(p.y - box.baseCenter.y - box.height))
            sum += distance * distance
        }
        return (sum / Float(points.count)).squareRoot()
    }

    static func percentile(_ values: [Float], _ q: Float) -> Float {
        let sorted = values.sorted()
        let index = Int((Float(sorted.count - 1) * q).rounded())
        return sorted[min(max(index, 0), sorted.count - 1)]
    }
}

/// Picks the furniture out of a room scan: the points connected to where the person aimed.
enum FurnitureIsolation {
    /// Floor points (within `floorTolerance` of the floor) are dropped, then the points are
    /// grouped into `voxel`-sized cells and only the group touching `seed` is kept.
    static func isolate(_ points: [SIMD3<Float>], seed: SIMD3<Float>, floorY: Float,
                        voxel: Float = 0.03, floorTolerance: Float = 0.015) -> [SIMD3<Float>] {
        let raised = points.filter { $0.y > floorY + floorTolerance }
        func cell(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>((p / voxel).rounded(.down)) }

        var cells: [SIMD3<Int32>: [Int]] = [:]
        for (index, point) in raised.enumerated() { cells[cell(point), default: []].append(index) }

        // Start from the occupied cell nearest the aim point, if one is close by.
        let aim = cell(seed)
        guard let start = cells.keys
            .filter({ simd_reduce_max(abs($0 &- aim)) <= 3 })
            .min(by: { simd_length_squared(SIMD3<Float>($0 &- aim)) < simd_length_squared(SIMD3<Float>($1 &- aim)) })
        else { return [] }

        var seen: Set<SIMD3<Int32>> = [start]
        var queue = [start]
        while let current = queue.popLast() {
            for dx in Int32(-1)...1 {
                for dy in Int32(-1)...1 {
                    for dz in Int32(-1)...1 {
                        let next = current &+ SIMD3(dx, dy, dz)
                        if cells[next] != nil, seen.insert(next).inserted { queue.append(next) }
                    }
                }
            }
        }
        return cells.filter { seen.contains($0.key) }.flatMap(\.value).map { raised[$0] }
    }
}
