import Foundation

/// Code decides the 3D geometry, not the AI. Turns a `PlanDraft` into a `Plan` with positions, rotations
/// and the overall size.
///
/// Convention (RealityKit can adapt it in one place): units are mm, y is up, the origin is the floor centre.
/// A panel's local axes are width → x, height → y, thickness → z, and its position is its centre.
/// Rotations are degrees about x, then y, then z. Thickness comes from the source part.
public enum Layout {
    /// Used when a draft names a source part that isn't in the inventory (the validator rejects it anyway).
    public static let placeholderThickness = 18.0
    /// Space between parts laid side by side on the floor.
    public static let gap = 20.0

    /// Lying flat: the panel's height runs along z and its thickness along y.
    static let flat = Vector3(x: 90, y: 0, z: 0)
    /// Standing upright, facing forward: width along x, height up, thickness along z.
    static let upright = Vector3(x: 0, y: 0, z: 0)
    /// Standing upright, turned sideways: width along z, height up, thickness along x.
    static let sideways = Vector3(x: 0, y: 90, z: 0)

    public static func plan(from draft: PlanDraft, inventory: Inventory, id: String) -> Plan {
        let items = draft.newParts.enumerated().map { index, part in
            Item(index: index, part: part, thickness: inventory.parts.first { $0.id == part.sourcePartID }?.thicknessMm
                 ?? placeholderThickness)
        }
        var placed: [Int: Placed]
        switch draft.template {
        case .bench: placed = bench(items)
        case .bookshelf: placed = bookshelf(items)
        case .noCut: placed = [:]
        }
        let rest = items.filter { placed[$0.index] == nil }
        let mainBounds = Bounds(items.compactMap { item in placed[item.index].map { item.box(at: $0) } })
        let startX = placed.isEmpty ? -rowLength(rest) / 2 : mainBounds.max.x + gap
        for (index, spot) in row(rest, startX: startX) { placed[index] = spot }

        // Every item is placed by now (the template places its own, the row takes the rest).
        let newParts = items.compactMap { item in
            placed[item.index].map { spot in
                NewPart(heightMm: item.part.heightMm, name: item.part.name, positionMm: spot.position,
                        role: item.part.role, rotationDeg: spot.rotation, sourcePartID: item.part.sourcePartID,
                        spanMm: item.part.spanMm, widthMm: item.part.widthMm)
            }
        }
        let overall = Bounds(items.compactMap { item in placed[item.index].map { item.box(at: $0) } }).size
        return Plan(hardware: draft.hardware, id: id, newParts: newParts, overallMm: overall, scanID: inventory.scanID,
                    source: .ginkgo, steps: draft.steps, template: draft.template)
    }

    // MARK: - Templates

    /// Seats lie flat on top of two upright supports at the seat's ends. Several seats sit side by side along z.
    static func bench(_ items: [Item]) -> [Int: Placed] {
        let seats = items.filter { $0.part.role == .seat || $0.part.role == .shelf }
        let supports = items.filter { $0.part.role == .support || $0.part.role == .side }
        let legHeight = supports.map(\.part.heightMm).max() ?? 0
        let seatWidth = seats.map(\.part.widthMm).max() ?? 0
        var placed: [Int: Placed] = [:]
        for (number, support) in supports.enumerated() {
            let side: Double = number.isMultiple(of: 2) ? -1 : 1
            let x = side * (seatWidth / 2 - support.thickness / 2)
            placed[support.index] = Placed(position: Vector3(x: x, y: support.part.heightMm / 2, z: 0), rotation: sideways)
        }
        var z = -seats.reduce(0) { $0 + $1.part.heightMm } / 2
        for seat in seats {
            let y = legHeight + seat.thickness / 2
            placed[seat.index] = Placed(position: Vector3(x: 0, y: y, z: z + seat.part.heightMm / 2), rotation: flat)
            z += seat.part.heightMm
        }
        return placed
    }

    /// Two upright sides with the shelves evenly spaced between them, bottom to top, and a back panel behind.
    static func bookshelf(_ items: [Item]) -> [Int: Placed] {
        let shelves = items.filter { $0.part.role == .shelf || $0.part.role == .seat }
        let sides = items.filter { $0.part.role == .side || $0.part.role == .support }
        let backs = items.filter { $0.part.role == .back }
        let shelfWidth = shelves.map(\.part.widthMm).max() ?? 0
        let sideHeight = sides.map(\.part.heightMm).max() ?? 0
        let depth = sides.map(\.part.widthMm).max() ?? 0
        var placed: [Int: Placed] = [:]
        for (number, side) in sides.enumerated() {
            let sign: Double = number.isMultiple(of: 2) ? -1 : 1
            let x = sign * (shelfWidth / 2 + side.thickness / 2)
            placed[side.index] = Placed(position: Vector3(x: x, y: side.part.heightMm / 2, z: 0), rotation: sideways)
        }
        for (number, shelf) in shelves.enumerated() {
            let low = shelf.thickness / 2
            let step = shelves.count > 1 ? (sideHeight - shelf.thickness) / Double(shelves.count - 1) : 0
            placed[shelf.index] = Placed(position: Vector3(x: 0, y: low + Double(number) * step, z: 0), rotation: flat)
        }
        for back in backs {
            let z = -depth / 2 + back.thickness / 2   // flush with the back edges of the sides
            placed[back.index] = Placed(position: Vector3(x: 0, y: back.part.heightMm / 2, z: z), rotation: upright)
        }
        return placed
    }

    /// Parts standing upright on the floor in a row along x, 20 mm apart, starting at `startX`.
    static func row(_ items: [Item], startX: Double) -> [Int: Placed] {
        var placed: [Int: Placed] = [:]
        var x = startX
        for item in items {
            placed[item.index] = Placed(position: Vector3(x: x + item.part.widthMm / 2, y: item.part.heightMm / 2, z: 0),
                                        rotation: upright)
            x += item.part.widthMm + gap
        }
        return placed
    }

    static func rowLength(_ items: [Item]) -> Double {
        items.reduce(0) { $0 + $1.part.widthMm } + gap * Double(max(0, items.count - 1))
    }
}

/// A draft part with its place in the draft and its thickness.
struct Item {
    var index: Int
    var part: DraftPart
    var thickness: Double

    /// The axis-aligned box this panel fills when placed.
    func box(at spot: Placed) -> Bounds {
        let size = Rotation.extent(of: Vector3(x: part.widthMm, y: part.heightMm, z: thickness), rotatedBy: spot.rotation)
        let half = Vector3(x: size.x / 2, y: size.y / 2, z: size.z / 2)
        let center = spot.position
        return Bounds(min: Vector3(x: center.x - half.x, y: center.y - half.y, z: center.z - half.z),
                      max: Vector3(x: center.x + half.x, y: center.y + half.y, z: center.z + half.z))
    }
}

struct Placed: Equatable {
    var position: Vector3
    var rotation: Vector3
}

/// An axis-aligned box in mm.
struct Bounds: Equatable {
    var min: Vector3
    var max: Vector3

    init(min: Vector3, max: Vector3) {
        self.min = min
        self.max = max
    }

    /// The box around all `boxes`; a zero box at the origin when there are none.
    init(_ boxes: [Bounds]) {
        guard let first = boxes.first else {
            self.init(min: Vector3(x: 0, y: 0, z: 0), max: Vector3(x: 0, y: 0, z: 0))
            return
        }
        self = boxes.dropFirst().reduce(first) { total, box in
            Bounds(min: Vector3(x: Swift.min(total.min.x, box.min.x), y: Swift.min(total.min.y, box.min.y),
                                z: Swift.min(total.min.z, box.min.z)),
                   max: Vector3(x: Swift.max(total.max.x, box.max.x), y: Swift.max(total.max.y, box.max.y),
                                z: Swift.max(total.max.z, box.max.z)))
        }
    }

    var size: Vector3 {
        Vector3(x: Rotation.clean(max.x - min.x), y: Rotation.clean(max.y - min.y), z: Rotation.clean(max.z - min.z))
    }
}

/// Rotations in degrees, applied about x, then y, then z.
enum Rotation {
    /// The size of the axis-aligned box around a panel of `size` after rotating it.
    static func extent(of size: Vector3, rotatedBy degrees: Vector3) -> Vector3 {
        let matrix = multiply(multiply(about(.z, degrees.z), about(.y, degrees.y)), about(.x, degrees.x))
        let local = [size.x, size.y, size.z]
        let world = matrix.map { row in zip(row, local).reduce(0) { $0 + abs($1.0) * $1.1 } }
        return Vector3(x: clean(world[0]), y: clean(world[1]), z: clean(world[2]))
    }

    enum Axis { case x, y, z }

    static func about(_ axis: Axis, _ degrees: Double) -> [[Double]] {
        let angle = degrees * .pi / 180
        let (cosine, sine) = (cos(angle), sin(angle))
        switch axis {
        case .x: return [[1, 0, 0], [0, cosine, -sine], [0, sine, cosine]]
        case .y: return [[cosine, 0, sine], [0, 1, 0], [-sine, 0, cosine]]
        case .z: return [[cosine, -sine, 0], [sine, cosine, 0], [0, 0, 1]]
        }
    }

    static func multiply(_ lhs: [[Double]], _ rhs: [[Double]]) -> [[Double]] {
        (0..<3).map { row in (0..<3).map { column in (0..<3).reduce(0) { $0 + lhs[row][$1] * rhs[$1][column] } } }
    }

    /// Removes floating-point dust such as 300.00000000000006 from cos(90°), to 1/1000 mm.
    static func clean(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000 + 0.0
    }
}
