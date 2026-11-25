import Foundation

/// How a part is held on.
public enum Fastener: String, Codable, Sendable, CaseIterable {
    case screws
    case camLocks = "cam_locks"
    case nails
    case staples
    case dowels
    case glue
    case clips
    case unknown
}

/// One step of Gemini's answer.
public struct TakeApartReadingStep: Codable, Sendable, Equatable {
    public var partIDs: [String]
    public var action: String
    public var fastener: Fastener

    enum CodingKeys: String, CodingKey {
        case partIDs = "part_ids"
        case action, fastener
    }

    public init(partIDs: [String], action: String, fastener: Fastener) {
        self.partIDs = partIDs
        self.action = action
        self.fastener = fastener
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        partIDs = try c.decode([String].self, forKey: .partIDs)
        action = try c.decode(String.self, forKey: .action)
        // A fastener word the app doesn't know is "unknown", never a failed reading.
        fastener = Fastener(rawValue: (try? c.decode(String.self, forKey: .fastener)) ?? "") ?? .unknown
    }
}

/// Gemini's answer: the order to take the piece apart in, part by part. Only a suggestion until `TakeApart.guide` checks it.
public struct TakeApartReading: Codable, Sendable, Equatable {
    public typealias Step = TakeApartReadingStep
    public var steps: [Step]

    public init(steps: [Step]) { self.steps = steps }
}

/// One step on the take-apart screen.
public struct TakeApartStep: Sendable, Equatable {
    public var number: Int
    /// The parts that come off in this step, by id.
    public var partIDs: [String]
    public var action: String
    /// The tools for the fastener, chosen by code, not by the model.
    public var tools: String
    /// False when Ginkgo's template wrote it.
    public var fromGemini: Bool
}

public struct TakeApartGuide: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        case gemini
        case template
    }

    public var steps: [TakeApartStep]
    public var source: Source
    /// What code changed or wants checked, in plain words.
    public var notes: [String]
}

/// Step 2: how to take the piece apart. Gemini reads the photo and suggests the order and fasteners; code keeps only
/// steps about parts in the confirmed list, adds a standard step for every part Gemini left out, and picks the tools.
/// With no network, the template writes the whole guide from the parts list.
public enum TakeApart {
    public static let maxSteps = 20

    public static let safetyStep = "Empty it, take out any glass or mirrors, and lay it on a clear floor before you start."

    public static let prompt = """
        This piece of furniture will be taken apart so its panels can be reused. Using the photo and the parts list below,
        give the order to take it apart in, one step per part or group of parts that come off together.
        Each step names the part ids it frees (only ids from the list), says in one or two plain sentences what to do,
        and names how the part is held: screws, cam_locks, nails, staples, dowels, glue, clips or unknown.
        Start with what comes off first (drawers, doors, shelves resting on pins), then the back, then the top, then the sides.
        If you can't see how a part is held, say unknown. Never invent parts.
        """

    /// The JSON shape Gemini must answer with.
    public static let responseSchema: ParamSchema = .object([
        ParamProperty(name: "steps", schema: .array(.object([
            ParamProperty(name: "part_ids", schema: .array(.string("A part id from the list."), "The parts this step frees.")),
            ParamProperty(name: "action", schema: .string("What to do, in one or two plain sentences.")),
            ParamProperty(name: "fastener", schema: .enumeration(Fastener.allCases.map(\.rawValue), "How the parts are held.")),
        ], "One take-apart step."), "The steps, first to last.")),
    ], "How to take the piece apart.")

    /// The prompt with the confirmed parts, so Gemini can only name parts that exist.
    public static func prompt(for inventory: Inventory) -> String {
        let lines = inventory.parts.map { "- \($0.id): \($0.type.rawValue), \(Format.mm($0.widthMm)) × \(Format.mm($0.heightMm)) mm" }
        return prompt + "\nParts:\n" + lines.joined(separator: "\n")
    }

    public static func parse(_ text: String) throws -> TakeApartReading {
        try JSONDecoder().decode(TakeApartReading.self, from: Data(text.utf8))
    }

    /// The tools for a fastener. Code decides, so a nail step never says "screwdriver".
    public static func tools(for fastener: Fastener) -> String {
        switch fastener {
        case .screws: return "Phillips screwdriver (keep the screws for later)"
        case .camLocks: return "Flat screwdriver: turn each cam lock to the left until it loosens"
        case .nails, .staples: return "Pry bar and hammer: lever close to each nail, slowly"
        case .dowels: return "Rubber mallet: tap the joint apart, then pull the dowels"
        case .glue: return "Pry bar: work along the joint slowly; glued edges may tear"
        case .clips: return "Flat screwdriver: press each clip in and lift the part"
        case .unknown: return "Screwdriver and pry bar: look for screws or cam locks first"
        }
    }

    /// Checks Gemini's reading against the confirmed parts. Nil reading (no network or no answer) → the template.
    public static func guide(_ reading: TakeApartReading?, inventory: Inventory) -> TakeApartGuide {
        guard let reading, !reading.steps.isEmpty else { return template(inventory) }
        let known = Set(inventory.parts.map(\.id))
        var notes: [String] = []
        var kept: [Kept] = []
        var dropped = 0
        for step in reading.steps.prefix(maxSteps) {
            let ids = step.partIDs.filter(known.contains)
            let action = step.action.trimmingCharacters(in: .whitespacesAndNewlines)
            if ids.isEmpty || ids.count != step.partIDs.count || action.isEmpty {
                dropped += 1
                continue
            }
            kept.append(Kept(ids: ids, action: action, fastener: step.fastener, gemini: true))
        }
        if dropped > 0 {
            notes.append(dropped == 1 ? "Ginkgo left out 1 step that named a part not in your list."
                                      : "Ginkgo left out \(dropped) steps that named parts not in your list.")
        }
        if reading.steps.count > maxSteps {
            notes.append("Gemini gave more than \(maxSteps) steps; only the first \(maxSteps) were kept.")
        }
        guard !kept.isEmpty else {
            var fallback = template(inventory)
            fallback.notes = notes + fallback.notes
            return fallback
        }
        let covered = Set(kept.flatMap(\.ids))
        let missing = ordered(inventory.parts.filter { !covered.contains($0.id) })
        for part in missing {
            kept.append(Kept(ids: [part.id], action: templateAction(part), fastener: .unknown, gemini: false))
            notes.append("Gemini didn't say how the \(Format.partName(part.id)) comes off, so Ginkgo added a standard step.")
        }
        if kept.contains(where: { $0.fastener == .glue }) {
            notes.append("Glued joints can tear the edges: scan each panel after it's off so the plan uses only sound wood.")
        }
        return TakeApartGuide(steps: numbered(kept), source: .gemini, notes: notes)
    }

    /// The generic guide from the parts list: what usually comes off first, then the back, top, rails, sides and legs.
    public static func template(_ inventory: Inventory) -> TakeApartGuide {
        let steps = ordered(inventory.parts).map {
            Kept(ids: [$0.id], action: templateAction($0), fastener: .unknown, gemini: false)
        }
        return TakeApartGuide(steps: numbered(steps), source: .template,
                              notes: ["A standard order for a piece like this. Look at each joint before you pull."])
    }

    static func order(_ type: TypeEnum) -> Int {
        switch type {
        case .drawerFront, .drawerBox: return 0
        case .shelf: return 1
        case .back: return 2
        case .top: return 3
        case .rail: return 4
        case .side: return 5
        case .leg: return 6
        }
    }

    static func ordered(_ parts: [Part]) -> [Part] {
        parts.enumerated().sorted { (order($0.element.type), $0.offset) < (order($1.element.type), $1.offset) }.map(\.element)
    }

    static func templateAction(_ part: Part) -> String {
        let name = Format.partName(part.id)
        switch part.type {
        case .drawerFront, .drawerBox: return "Pull the \(name) all the way out and lift it off its runners."
        case .shelf: return "Lift the \(name) off its pins, or undo its screws from underneath."
        case .back: return "Take out the nails or staples around the edge of the \(name) and lift it away."
        case .top: return "Undo the screws or cam locks under the \(name) and lift it straight up."
        case .rail: return "Undo the screws holding the \(name) to the sides and pull it free."
        case .side: return "Undo what still holds the \(name) and lift it away."
        case .leg: return "Unscrew the \(name), or undo the bolts holding it on."
        }
    }

    /// A step on its way to the screen: whose parts, what to do, how they're held, and who wrote it.
    struct Kept {
        var ids: [String]
        var action: String
        var fastener: Fastener
        var gemini: Bool
    }

    static func numbered(_ steps: [Kept]) -> [TakeApartStep] {
        let safety = TakeApartStep(number: 1, partIDs: [], action: safetyStep, tools: "", fromGemini: false)
        return [safety] + steps.enumerated().map { offset, step in
            TakeApartStep(number: offset + 2, partIDs: step.ids, action: step.action, tools: tools(for: step.fastener),
                          fromGemini: step.gemini)
        }
    }
}
