import Foundation

/// One cut to make from a source part: the new part's name and finished size, in mm.
public struct CutRequest: Sendable, Equatable {
    public var name: String
    public var widthMm: Double
    public var heightMm: Double

    public init(name: String, widthMm: Double, heightMm: Double) {
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
    }

    var isValid: Bool { widthMm.isFinite && heightMm.isFinite && widthMm > 0 && heightMm > 0 }
    var area: Double { widthMm * heightMm }
}

/// Why a cut couldn't be placed.
public enum PackFailureReason: String, Sendable, Equatable {
    case invalidSize = "invalid_size"                 // zero, negative or not a number
    case tooBig = "too_big"                           // wouldn't fit even on a clear panel
    case blockedByKeepOuts = "blocked_by_keep_outs"   // fits the panel, but screw holes or damage are in the way
    case noRoomLeft = "no_room_left"                  // the panel's other cuts already use the space
}

/// A cut that doesn't fit, with numbers and a hint the agent can act on.
public struct PackFailure: Sendable, Equatable {
    public var name: String
    public var reason: PackFailureReason
    /// The reserved size: the cut plus the margin (or the panel size for a whole-part reuse).
    public var neededMm: [Double]
    public var availableMm: [Double]
    /// How much too big the cut is for the panel, in its better orientation (0 when only space is the problem).
    public var shortByMm: Double
    /// The largest height (in 10 mm steps) that fits when the width is kept.
    public var maxHeightMm: Double?
    /// The largest width (in 10 mm steps) that fits when the height is kept.
    public var maxWidthMm: Double?
    public var hint: String
}

/// The cutting diagram for one source part.
public struct PackResult: Sendable, Equatable {
    public var sourcePartID: String
    /// Where each cut goes. Width and height are the footprint on the panel, so a rotated cut has them swapped.
    public var placements: [Placement]
    public var failures: [PackFailure]
    /// Panel left over to the right of, and above, every reserved box.
    public var spareWidthMm: Double
    public var spareHeightMm: Double
}

/// Places rectangular cuts on a panel: greedy, bottom-left first, around keep-outs. Deterministic.
public enum Packer {
    /// 3 mm saw kerf + 5 mm measurement margin, added to each dimension of every cut.
    public static let margin = 8.0 // MUTANT:margin
    /// A new part this close to the source size (in either orientation) is the whole part, reused uncut.
    public static let wholePartTolerance = 1.0
    static let hintStep = 10.0

    public static func pack(source: Part, cuts: [CutRequest]) -> PackResult {
        var state = PackState(source: source)
        for cut in cuts where !cut.isValid {
            state.failures.append(invalidFailure(cut, source: source))
        }
        for cut in largestFirst(cuts.filter(\.isValid)) {
            state.add(cut)
        }
        return PackResult(
            sourcePartID: source.id,
            placements: state.placements,
            failures: state.failures,
            spareWidthMm: source.widthMm - (state.boxes.map(\.maxX).max() ?? 0),
            spareHeightMm: source.heightMm - (state.boxes.map(\.maxY).max() ?? 0))
    }

    /// Largest area first; ties by name, then by input order.
    static func largestFirst(_ cuts: [CutRequest]) -> [CutRequest] {
        cuts.enumerated().sorted { lhs, rhs in
            if lhs.element.area != rhs.element.area { return lhs.element.area > rhs.element.area }
            if lhs.element.name != rhs.element.name { return lhs.element.name < rhs.element.name }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// The box a cut reserves: the whole panel for a whole-part reuse, otherwise the cut plus the margin.
    static func reserved(for cut: CutRequest, on source: Part) -> Reserved {
        func near(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) <= wholePartTolerance }
        if near(cut.widthMm, source.widthMm) && near(cut.heightMm, source.heightMm) {
            return Reserved(width: source.widthMm, height: source.heightMm, wholeRotated: false)
        }
        if near(cut.widthMm, source.heightMm) && near(cut.heightMm, source.widthMm) {
            return Reserved(width: source.widthMm, height: source.heightMm, wholeRotated: true)
        }
        return Reserved(width: cut.widthMm + margin, height: cut.heightMm + margin, wholeRotated: nil)
    }

    /// The first spot, by (y, x), where a box fits inside the panel without overlapping any obstacle.
    /// Corners are 0 and the right/top edges of every obstacle. Unrotated is tried before rotated.
    static func findSpot(width: Double, height: Double, on source: Part, avoiding obstacles: [Box]) -> Spot? {
        let xs = Set([0] + obstacles.map(\.maxX)).sorted()
        let ys = Set([0] + obstacles.map(\.maxY)).sorted()
        for y in ys {
            for x in xs {
                for rotated in [false, true] {
                    let box = Box(x: x, y: y, width: rotated ? height : width, height: rotated ? width : height)
                    if box.fits(width: source.widthMm, height: source.heightMm) && !obstacles.contains(where: box.overlaps) {
                        return Spot(box: box, rotated: rotated)
                    }
                }
            }
        }
        return nil
    }
}

/// A rectangle in panel coordinates (mm, from the bottom-left corner).
struct Box: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var maxX: Double { x + width }
    var maxY: Double { y + height }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: Rect) {
        self.init(x: rect.xMm, y: rect.yMm, width: rect.widthMm, height: rect.heightMm)
    }

    func fits(width panelWidth: Double, height panelHeight: Double) -> Bool {
        maxX <= panelWidth && maxY <= panelHeight // MUTANT:fit-compare
    }

    /// Strict: boxes that only touch along an edge don't overlap.
    func overlaps(_ other: Box) -> Bool {
        x < other.maxX && other.x < maxX && y < other.maxY && other.y < maxY // MUTANT:overlap
    }
}

/// The size a cut reserves. `wholeRotated` is set only for a whole-part reuse (true when it's turned 90°).
struct Reserved: Equatable {
    var width: Double
    var height: Double
    var wholeRotated: Bool?
}

struct Spot: Equatable {
    var box: Box
    var rotated: Bool
}

/// The panel as it fills up, cut by cut.
struct PackState {
    let source: Part
    var boxes: [Box] = []
    var placements: [Placement] = []
    var failures: [PackFailure] = []

    init(source: Part) {
        self.source = source
    }

    var keepOuts: [Box] { source.keepOuts.map(Box.init) }

    mutating func add(_ cut: CutRequest) {
        let size = Packer.reserved(for: cut, on: source)
        let obstacles = size.wholeRotated == nil ? boxes + keepOuts : boxes   // an uncut part ignores keep-outs
        guard let spot = Packer.findSpot(width: size.width, height: size.height, on: source, avoiding: obstacles) else {
            failures.append(Packer.failure(for: cut, size: size, placed: boxes, source: source))
            return
        }
        boxes.append(spot.box)
        // The cut sits centred in its reserved box; a whole part fills the panel.
        let inset = size.wholeRotated == nil ? Packer.margin / 2 : 0
        placements.append(Placement(
            heightMm: spot.box.height - 2 * inset, newPart: cut.name, rotated: size.wholeRotated ?? spot.rotated,
            sourcePartID: source.id, widthMm: spot.box.width - 2 * inset,
            xMm: spot.box.x + inset, yMm: spot.box.y + inset))
    }
}

// MARK: - Explaining failures

extension Packer {
    static func invalidFailure(_ cut: CutRequest, source: Part) -> PackFailure {
        PackFailure(
            name: cut.name, reason: .invalidSize, neededMm: [cut.widthMm, cut.heightMm],
            availableMm: [source.widthMm, source.heightMm], shortByMm: 0, maxHeightMm: nil, maxWidthMm: nil,
            hint: "Width and height must be more than 0 mm.")
    }

    static func failure(for cut: CutRequest, size: Reserved, placed: [Box], source: Part) -> PackFailure {
        let reason: PackFailureReason
        if findSpot(width: size.width, height: size.height, on: source, avoiding: []) == nil {
            reason = .tooBig
        } else if findSpot(width: size.width, height: size.height, on: source, avoiding: placed) != nil {
            reason = .blockedByKeepOuts
        } else {
            reason = .noRoomLeft
        }
        let straight = max(0, size.width - source.widthMm, size.height - source.heightMm)
        let turned = max(0, size.height - source.widthMm, size.width - source.heightMm)
        var failure = PackFailure(
            name: cut.name, reason: reason, neededMm: [size.width, size.height],
            availableMm: [source.widthMm, source.heightMm], shortByMm: min(straight, turned),
            maxHeightMm: nil, maxWidthMm: nil, hint: "This part is reused whole, and another cut already uses it.")
        guard size.wholeRotated == nil else { return failure }

        let obstacles = placed + source.keepOuts.map(Box.init)
        func fits(_ width: Double, _ height: Double) -> Bool {
            findSpot(width: width + margin, height: height + margin, on: source, avoiding: obstacles) != nil
        }
        failure.maxHeightMm = largest(below: cut.heightMm) { fits(cut.widthMm, $0) }
        failure.maxWidthMm = largest(below: cut.widthMm) { fits($0, cut.heightMm) }
        failure.hint = hint(for: cut, maxHeight: failure.maxHeightMm, maxWidth: failure.maxWidthMm)
        return failure
    }

    /// Searches downward in 10 mm steps for the first size that fits.
    static func largest(below start: Double, fits: (Double) -> Bool) -> Double? {
        var candidate = start - hintStep
        while candidate > 0 {
            if fits(candidate) { return candidate }
            candidate -= hintStep
        }
        return nil
    }

    static func hint(for cut: CutRequest, maxHeight: Double?, maxWidth: Double?) -> String {
        var options: [String] = []
        if let maxHeight {
            options.append("height \(Format.mm(maxHeight)) mm or less at width \(Format.mm(cut.widthMm)) mm")
        }
        if let maxWidth {
            options.append("width \(Format.mm(maxWidth)) mm or less at height \(Format.mm(cut.heightMm)) mm")
        }
        return options.isEmpty
            ? "No smaller size with the same width or height fits."
            : "Fits with " + options.joined(separator: ", or ") + "."
    }
}
