import ARKit
import simd

/// ARKit's room mesh, read out as plain points: what the walk-around scan measures.
/// Runs only on LiDAR iPhones; the math it feeds (FurnitureIsolation, BoxFit) is tested separately.
@MainActor
final class MeshCapture {
    let session = ARSession()

    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() { session.pause() }

    /// Room surfaces that are never furniture.
    private static let ignored: Set<ARMeshClassification> = [.wall, .floor, .ceiling, .door, .window]

    /// World-space vertices of every mesh face not classified as room structure.
    func furniturePoints() -> [SIMD3<Float>] {
        meshAnchors.flatMap { anchor in
            let geometry = anchor.geometry
            let vertices = Self.vertices(of: geometry, transform: anchor.transform)
            var keep = [Bool](repeating: false, count: vertices.count)
            for face in 0..<geometry.faces.count where !Self.ignored.contains(Self.classification(of: geometry, face: face)) {
                for corner in Self.vertexIndices(of: geometry, face: face) where corner < keep.count { keep[corner] = true }
            }
            return vertices.indices.filter { keep[$0] }.map { vertices[$0] }
        }
    }

    /// The floor's height: the lowest horizontal plane ARKit found, else the lowest floor-classified mesh point.
    func floorY() -> Float? {
        let anchors = session.currentFrame?.anchors ?? []
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }.filter { $0.alignment == .horizontal }
        if let lowest = planes.map({ $0.transform.columns.3.y }).min() { return lowest }
        return meshAnchors.flatMap { anchor -> [Float] in
            let geometry = anchor.geometry
            let vertices = Self.vertices(of: geometry, transform: anchor.transform)
            return (0..<geometry.faces.count)
                .filter { Self.classification(of: geometry, face: $0) == .floor }
                .flatMap { Self.vertexIndices(of: geometry, face: $0) }
                .compactMap { $0 < vertices.count ? vertices[$0].y : nil }
        }.min()
    }

    /// Where the middle of the screen hits the scanned furniture: the aim point.
    func aimPoint() -> SIMD3<Float>? {
        guard let frame = session.currentFrame else { return nil }
        let query = frame.raycastQuery(from: CGPoint(x: 0.5, y: 0.5), allowing: .estimatedPlane, alignment: .any)
        return session.raycast(query).first.map {
            SIMD3($0.worldTransform.columns.3.x, $0.worldTransform.columns.3.y, $0.worldTransform.columns.3.z)
        }
    }

    private var meshAnchors: [ARMeshAnchor] {
        (session.currentFrame?.anchors ?? []).compactMap { $0 as? ARMeshAnchor }
    }

    private static func vertices(of geometry: ARMeshGeometry, transform: simd_float4x4) -> [SIMD3<Float>] {
        let source = geometry.vertices
        let base = source.buffer.contents().advanced(by: source.offset)
        return (0..<source.count).map { index in
            let p = base.advanced(by: index * source.stride).assumingMemoryBound(to: (Float, Float, Float).self).pointee
            let world = transform * SIMD4(p.0, p.1, p.2, 1)
            return SIMD3(world.x, world.y, world.z)
        }
    }

    private static func vertexIndices(of geometry: ARMeshGeometry, face: Int) -> [Int] {
        let faces = geometry.faces
        let base = faces.buffer.contents()
        return (0..<faces.indexCountPerPrimitive).map { corner in
            let offset = (face * faces.indexCountPerPrimitive + corner) * faces.bytesPerIndex
            return Int(base.advanced(by: offset).assumingMemoryBound(to: UInt32.self).pointee)
        }
    }

    private static func classification(of geometry: ARMeshGeometry, face: Int) -> ARMeshClassification {
        guard let source = geometry.classification else { return .none }
        let value = source.buffer.contents().advanced(by: source.offset + source.stride * face)
            .assumingMemoryBound(to: UInt8.self).pointee
        return ARMeshClassification(rawValue: Int(value)) ?? .none
    }
}
