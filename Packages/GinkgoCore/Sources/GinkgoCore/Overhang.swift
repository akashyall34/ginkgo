import Foundation

/// A part's footprint on the floor in the layout, mm: x side to side, z front to back.
struct Footprint: Equatable {
    var minX: Double
    var maxX: Double
    var minZ: Double
    var maxZ: Double
}

/// Tipping: a seat must not reach past its supports, or a person sitting on that edge tips the build.
/// Conservative statics: the build's own weight is given no credit, so no density or force is assumed. A sideways
/// push (what EN 1022 and ANSI/BIFMA X5.4 test) isn't modelled.
public enum Overhang {
    /// How far a seat may reach past its supports' footprint, mm.
    public static let toleranceMm = 1.0

    /// Judged only for a build that's assembled (not a whole-part reuse), with every seat and support actually placed
    /// on a panel and named once: otherwise its layout isn't real, and the plan is already rejected for that.
    static func violations(_ plan: Plan, parts: [String: Part], placed: Set<String>) -> [Violation] {
        let uprights = plan.newParts.filter { $0.role == .support || $0.role == .side }
        let structural = plan.newParts.filter { $0.role == .seat } + uprights
        guard plan.template != .noCut, !uprights.isEmpty,
              structural.allSatisfy({ placed.contains($0.name) }),
              Set(structural.map(\.name)).count == structural.count else { return [] }
        let feet = uprights.map { footprint($0, parts: parts) }
        let base = Footprint(minX: feet.map(\.minX).min() ?? 0, maxX: feet.map(\.maxX).max() ?? 0,
                             minZ: feet.map(\.minZ).min() ?? 0, maxZ: feet.map(\.maxZ).max() ?? 0)
        return plan.newParts.filter { $0.role == .seat }.compactMap { seat in
            let top = footprint(seat, parts: parts)
            let overhangs: [(String, Double)] = [
                ("left end", base.minX - top.minX), ("right end", top.maxX - base.maxX),
                ("back edge", base.minZ - top.minZ), ("front edge", top.maxZ - base.maxZ),
            ]
            guard let worst = overhangs.max(by: { $0.1 < $1.1 }), worst.1 > toleranceMm else { return nil }
            return Violation(code: .unstable,
                             message: "\(seat.name): overhangs its supports by \(Format.mm(worst.1)) mm at the \(worst.0), "
                                + "so someone sitting there would tip it. Move the supports out to the edges or shorten the seat.",
                             newPart: seat.name)
        }
    }

    /// From the part's size, rotation and the thickness of the panel it's cut from.
    static func footprint(_ part: NewPart, parts: [String: Part]) -> Footprint {
        let thickness = parts[part.sourcePartID]?.thicknessMm ?? 0
        let extent = Rotation.extent(of: Vector3(x: part.widthMm, y: part.heightMm, z: thickness), rotatedBy: part.rotationDeg)
        return Footprint(minX: part.positionMm.x - extent.x / 2, maxX: part.positionMm.x + extent.x / 2,
                         minZ: part.positionMm.z - extent.z / 2, maxZ: part.positionMm.z + extent.z / 2)
    }
}
