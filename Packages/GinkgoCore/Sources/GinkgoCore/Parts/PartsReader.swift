import Foundation

/// Reads the parts of a piece of furniture from one photo. AI suggests, code decides:
/// Gemini only says what the parts are and where they are in the photo; code turns that into millimetres
/// using the LiDAR measurement, and flags anything the user should check. Gemini's own size guesses are a
/// cross-check only. Hidden parts are never invented by code: Gemini lists them, and they're flagged "measure it".
public enum PartsReader {
    /// A part is flagged when Gemini's size guess is more than 15% away from the size code worked out.
    public static let flagTolerance = 0.15
    /// Assumed panel thickness until the user confirms it (legs use their own width).
    public static let assumedThicknessMm = 18.0
    /// Gemini's image coordinates run from 0 to 1000.
    static let scale = 1000.0

    public static let prompt = """
        You are looking at one piece of furniture that will be taken apart and reused.
        List every part that could be salvaged: top or seat board, sides, back, shelves, drawer fronts, drawer boxes,
        legs, and rails (the horizontal boards under a seat or top, also called aprons).
        For each part you can see, give box_2d as [ymin, xmin, ymax, xmax] on a 0-1000 scale, tightly around its visible face.
        Also list parts that must exist but are hidden (for example the back legs or the side rails), without box_2d.
        Mark damaged parts. Mark padded or fabric-covered parts as upholstered, and bent parts like curved legs as curved.
        Guess each part's material: solid_wood, plywood, particleboard_mdf, plastic or cardboard.
        Furniture is not only wood: plastic storage carts and cardboard boxes count too.
        Estimate each part's width and height in millimetres, using the measured size below.
        Give furniture_box_2d around the whole piece. Never invent parts that a piece like this would not have.
        """

    /// The JSON shape Gemini must answer with (mirrors the `PartsReading` schema).
    public static let responseSchema: ParamSchema = .object([
        ParamProperty(name: "furniture_box_2d", schema: .array(.number("0-1000"), "[ymin, xmin, ymax, xmax] of the whole piece.")),
        ParamProperty(name: "parts", schema: .array(.object([
            ParamProperty(name: "type", schema: .enumeration(
                ["top", "side", "back", "shelf", "drawer_front", "drawer_box", "leg", "rail"], "What the part is.")),
            ParamProperty(name: "box_2d", schema: .array(.number("0-1000"), "[ymin, xmin, ymax, xmax]; leave out if hidden."),
                          required: false),
            ParamProperty(name: "damaged", schema: .boolean("Visible damage.")),
            ParamProperty(name: "material", schema: .enumeration(
                ["solid_wood", "plywood", "particleboard_mdf", "plastic", "cardboard"], "Your guess of the material."), required: false),
            ParamProperty(name: "upholstered", schema: .boolean("Covered in fabric or foam."), required: false),
            ParamProperty(name: "curved", schema: .boolean("Not a flat, straight board."), required: false),
            ParamProperty(name: "estimated_width_mm", schema: .number("Your width estimate in mm.")),
            ParamProperty(name: "estimated_height_mm", schema: .number("Your height estimate in mm.")),
            ParamProperty(name: "note", schema: .string("Anything else worth knowing."), required: false),
        ], "One salvageable part."), "Every salvageable part.")),
    ], "What you see in the photo.")

    /// The full request: the prompt with the measured size (mm: x = width, y = height, z = depth) and the photo.
    public static func request(photo: Data, mimeType: String, measured: Vector3, thinkingLevel: String? = "low") -> JSON {
        let size = "Measured size: \(Format.mm(measured.x)) mm wide, \(Format.mm(measured.y)) mm tall, "
            + "\(Format.mm(measured.z)) mm deep."
        let text: JSON = ["text": .string(prompt + "\n" + size)]
        let message = GeminiWire.userParts([text, GeminiWire.imagePart(data: photo, mimeType: mimeType)])
        return GeminiWire.jsonRequest(contents: [message], schema: responseSchema, thinkingLevel: thinkingLevel)
    }

    /// Reads Gemini's JSON answer. Throws when it doesn't match the shape.
    public static func parse(_ text: String) throws -> PartsReading {
        try JSONDecoder().decode(PartsReading.self, from: Data(text.utf8))
    }

    /// Turns a reading into an inventory for the user to confirm, plus everything they should check.
    public static func inventory(from reading: PartsReading, measured: Vector3,
                                 scanID: String) -> (inventory: Inventory, flags: [PartFlag]) {
        let furniture = Box2D(reading.furnitureBox2D)
        var flags = [
            PartFlag(message: "Confirm the material of each part (Gemini's guess is filled in; solid wood when it had none).",
                     partID: "all"),
            PartFlag(message: "Confirm each part's thickness: a typical value for its material is assumed (wood 18 mm, "
                + "plastic 3 mm, cardboard 4 mm), and legs use their width.", partID: "all"),
        ]
        if furniture == nil {
            let message = "Couldn't find the whole piece in the photo, so all sizes are Gemini's estimates. Measure them."
            flags.append(PartFlag(message: message, partID: "all"))
        }
        let ordered = reading.parts.enumerated().sorted { lhs, rhs in
            let left = Box2D(lhs.element.box2D)?.xmin ?? Double.infinity
            let right = Box2D(rhs.element.box2D)?.xmin ?? Double.infinity
            return left != right ? left < right : lhs.offset < rhs.offset
        }.map(\.element)
        var parts: [Part] = []
        for (detected, id) in zip(ordered, ids(for: ordered.map(\.type))) {
            let read = size(of: detected, furniture: furniture, measured: measured)
            guard read.width > 0, read.height > 0 else {
                flags.append(PartFlag(message: "\(id): couldn't work out its size. Add it by hand.", partID: id))
                continue
            }
            flags += partFlags(detected, id: id, read: read)
            let material = detected.material ?? .solidWood
            let thickness = detected.type == .leg ? read.width : MaterialCatalog.info(material).typicalThicknessMm
            parts.append(Part(damaged: detected.damaged, heightMm: read.height, id: id, keepOuts: [],
                              material: material, thicknessMm: thickness, type: detected.type,
                              widthMm: read.width))
        }
        return (Inventory(parts: parts, scanID: scanID), flags)
    }
}

// MARK: - Sizes, flags and IDs

/// Where a part's size came from: scaled from the photo by the measurement, or Gemini's estimate (and why).
enum SizeSource: Equatable {
    case photo
    case hidden
    case unplaceable
}

/// A size worked out by code, and where it came from.
struct ReadSize: Equatable {
    var width: Double
    var height: Double
    var source: SizeSource
}

extension PartsReader {
    static func size(of part: DetectedPart, furniture: Box2D?, measured: Vector3) -> ReadSize {
        let estimate = ReadSize(width: part.estimatedWidthMm.rounded(), height: part.estimatedHeightMm.rounded(),
                                source: part.box2D == nil ? .hidden : .unplaceable)
        guard let furniture, let box = Box2D(part.box2D) else { return estimate }
        let width = box.width * measured.x / furniture.width
        let height = box.height * measured.y / furniture.height
        switch part.type {
        case .top: return ReadSize(width: width.rounded(), height: measured.z.rounded(), source: .photo)
        case .side: return ReadSize(width: measured.z.rounded(), height: height.rounded(), source: .photo)
        case .back, .shelf, .drawerFront, .drawerBox, .leg, .rail:
            return ReadSize(width: width.rounded(), height: height.rounded(), source: .photo)
        }
    }

    static func partFlags(_ part: DetectedPart, id: String, read: ReadSize) -> [PartFlag] {
        var messages: [String] = []
        let size = "\(Format.mm(read.width)) × \(Format.mm(read.height)) mm"
        switch read.source {
        case .hidden: messages.append("not visible in the photo; Gemini guessed \(size). Measure it.")
        case .unplaceable: messages.append("couldn't place it in the photo; Gemini guessed \(size). Measure it.")
        case .photo:
            let gap = max(relativeGap(part.estimatedWidthMm, read.width), relativeGap(part.estimatedHeightMm, read.height))
            if gap > flagTolerance { // MUTANT:parts-flag
                let guess = "\(Format.mm(part.estimatedWidthMm)) × \(Format.mm(part.estimatedHeightMm)) mm"
                messages.append("Gemini guessed \(guess), but the photo and the measurement give \(size). Check this.")
            }
        }
        if part.damaged { messages.append("Gemini saw damage. Check it, and mark screw holes or damage as keep-outs.") }
        if part.upholstered == true {
            messages.append("padded: remove the fabric and foam first. "
                + "If the board underneath is MDF or particleboard, reuse it whole.")
        }
        if part.curved == true { messages.append("curved: only its straight part can be cut. Measure the straight length.") }
        return messages.map { PartFlag(message: "\(id): \($0)", partID: id) }
    }

    /// How far `guess` is from `actual`, as a share of `actual` (0.15 = 15%).
    static func relativeGap(_ guess: Double, _ actual: Double) -> Double {
        abs(guess - actual) / actual
    }

    /// Deterministic IDs: "top" and "back" when there's one; "side_left"/"side_right" for two sides; otherwise numbered.
    static func ids(for types: [TypeEnum]) -> [String] {
        var seen: [TypeEnum: Int] = [:]
        return types.map { type in
            let count = types.filter { $0 == type }.count
            let number = (seen[type] ?? 0) + 1
            seen[type] = number
            if count == 1 && (type == .top || type == .back) { return type.rawValue }
            if count == 2 && type == .side { return number == 1 ? "side_left" : "side_right" }
            return "\(type.rawValue)_\(number)"
        }
    }
}

/// A box on Gemini's 0-1000 image scale. Nil for anything that isn't four in-range numbers with positive size.
struct Box2D: Equatable {
    var ymin: Double
    var xmin: Double
    var ymax: Double
    var xmax: Double

    init?(_ values: [Double]?) {
        guard let values, values.count == 4, values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= PartsReader.scale }),
              values[0] < values[2], values[1] < values[3] else { return nil }
        (ymin, xmin, ymax, xmax) = (values[0], values[1], values[2], values[3])
    }

    var width: Double { xmax - xmin }
    var height: Double { ymax - ymin }
}
