import Foundation
import GinkgoCore
import simd

/// Where one panel sits, in meters, in RealityKit space (y up, origin on the floor at the center).
struct PanelPose: Equatable {
    /// Width, height and thickness of the panel, in meters.
    let size: SIMD3<Float>
    /// The panel's center.
    let position: SIMD3<Float>
    let rotation: simd_quatf
}

/// A piece of the new build: where it starts (inside the old furniture) and where it ends up.
struct TransformPiece: Equatable {
    let name: String
    let sourcePartID: String
    let start: PanelPose
    let end: PanelPose
}

/// Everything the transform animation shows: the pieces that move, and old panels the plan doesn't use.
struct TransformScene: Equatable {
    let pieces: [TransformPiece]
    let unused: [String: PanelPose]
}

/// Turns the inventory (the old furniture) and a plan (the new build) into start and end poses.
/// Follows the plan's layout convention: mm, y up, origin at the floor's center; a panel's width is
/// local x, height local y, thickness local z; rotations are degrees about x, then y, then z.
enum TransformLayout {
    static func meters(_ mm: Double) -> Float { Float(mm / 1000) }

    /// Degrees about x, then y, then z (each about the fixed world axes).
    static func rotation(degrees: Vector3) -> simd_quatf {
        let radians = { (d: Double) in Float(d * .pi / 180) }
        let x = simd_quatf(angle: radians(degrees.x), axis: SIMD3(1, 0, 0))
        let y = simd_quatf(angle: radians(degrees.y), axis: SIMD3(0, 1, 0))
        let z = simd_quatf(angle: radians(degrees.z), axis: SIMD3(0, 0, 1))
        return z * y * x
    }

    static let flat = Vector3(x: 90, y: 0, z: 0)
    static let upright = Vector3(x: 0, y: 0, z: 0)
    static let sideways = Vector3(x: 0, y: 90, z: 0)

    /// The old furniture assembled as a box: top on the sides, drawer front at the front, back at the back.
    static func furniture(_ inventory: Inventory) -> [String: PanelPose] {
        let top = inventory.parts.first { $0.type == .top }
        let sides = inventory.parts.filter { $0.type == .side }
        let width = meters(top?.widthMm ?? sides.first?.heightMm ?? 400)
        let depth = meters(top?.heightMm ?? sides.first?.widthMm ?? 400)
        let height = meters(sides.map(\.heightMm).max() ?? 500)

        var poses: [String: PanelPose] = [:]
        var sideIndex = 0
        for part in inventory.parts {
            let t = meters(part.thicknessMm)
            let size = SIMD3(meters(part.widthMm), meters(part.heightMm), t)
            let (position, turn): (SIMD3<Float>, Vector3)
            switch part.type {
            case .top:
                (position, turn) = (SIMD3(0, height + t / 2, 0), flat)
            case .side:
                let x = (sideIndex == 0 ? -1 : 1) * (width / 2 - t / 2)
                sideIndex += 1
                (position, turn) = (SIMD3(x, size.y / 2, 0), sideways)
            case .drawerFront:
                (position, turn) = (SIMD3(0, height - size.y / 2, depth / 2 - t / 2), upright)
            case .back:
                (position, turn) = (SIMD3(0, size.y / 2, -depth / 2 + t / 2), upright)
            case .shelf:
                (position, turn) = (SIMD3(0, height / 2, 0), flat)
            case .drawerBox, .leg, .rail:
                (position, turn) = (SIMD3(0, size.y / 2, 0), upright)
            }
            poses[part.id] = PanelPose(size: size, position: position, rotation: rotation(degrees: turn))
        }
        return poses
    }

    static func scene(plan: Plan, inventory: Inventory) -> TransformScene {
        let old = furniture(inventory)
        let pieces = plan.newParts.compactMap { part -> TransformPiece? in
            guard let source = old[part.sourcePartID] else { return nil }
            // A cut piece keeps its panel's thickness.
            let size = SIMD3(meters(part.widthMm), meters(part.heightMm), source.size.z)
            let end = PanelPose(size: size,
                                position: SIMD3(meters(part.positionMm.x), meters(part.positionMm.y), meters(part.positionMm.z)),
                                rotation: rotation(degrees: part.rotationDeg))
            // The cut piece starts where its panel is, so it visibly comes out of the old furniture.
            return TransformPiece(name: part.name, sourcePartID: part.sourcePartID,
                                  start: PanelPose(size: size, position: source.position, rotation: source.rotation), end: end)
        }
        let used = Set(plan.newParts.map(\.sourcePartID))
        return TransformScene(pieces: pieces, unused: old.filter { !used.contains($0.key) })
    }
}

extension TransformLayout {
    /// The sample furniture turned into the rule-based bench, whose 3D layout comes from Vivek's Layout code.
    static func example(bundle: Bundle = .main) -> TransformScene? {
        guard let url = bundle.url(forResource: "inventory", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let inventory = try? JSONDecoder().decode(Inventory.self, from: data),
              let bench = RuleBasedPlanner.bench(inventory: inventory) else { return nil }
        return scene(plan: bench.plan, inventory: inventory)
    }
}
