import Foundation

/// What a plain chatbot answers: the same photo and request, no tools, no checks.
public struct ChatbotAnswer: Codable, Equatable, Sendable {
    public var template: String
    public var parts: [ChatbotPart]
    public var steps: [String]

    public init(template: String, parts: [ChatbotPart], steps: [String]) {
        self.template = template
        self.parts = parts
        self.steps = steps
    }
}

public struct ChatbotPart: Codable, Equatable, Sendable {
    public var name: String
    /// The kind of original part it comes from, for example "top" or "side".
    public var from: String
    public var widthMm: Double
    public var heightMm: Double
    public var role: String

    public init(name: String, from: String, widthMm: Double, heightMm: Double, role: String) {
        self.name = name
        self.from = from
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case name, from, role
        case widthMm = "width_mm"
        case heightMm = "height_mm"
    }
}

/// The contrast: a chatbot's plan, run through the same validator as Ginkgo's. The spec's two variants:
/// photo only, and photo plus the correct dimensions ("just use the Measure app and ask a chatbot").
public enum ChatbotBaseline {
    public static let planID = "plan-chatbot-live"

    public static func prompt(measured: Vector3?) -> String {
        var text = "Here is a photo of a piece of furniture. Give me a cut list to turn its parts into a bench."
        if let measured {
            text += " It measures \(Format.mm(measured.x)) mm wide, \(Format.mm(measured.y)) mm tall "
                + "and \(Format.mm(measured.z)) mm deep."
        }
        return text
    }

    public static let responseSchema: ParamSchema = .object([
        ParamProperty(name: "template", schema: .enumeration(["bench", "bookshelf", "no_cut"], "What you'd build.")),
        ParamProperty(name: "parts", schema: .array(.object([
            ParamProperty(name: "name", schema: .string("The new part's name.")),
            ParamProperty(name: "from", schema: .enumeration(
                ["top", "side", "back", "shelf", "drawer_front", "drawer_box", "leg", "rail"], "Which original part it's cut from.")),
            ParamProperty(name: "width_mm", schema: .number("Width in mm.")),
            ParamProperty(name: "height_mm", schema: .number("Height in mm.")),
            ParamProperty(name: "role", schema: .enumeration(["seat", "shelf", "side", "support", "back", "other"], "Its job.")),
        ], "One part of the new build."), "The cut list.")),
        ParamProperty(name: "steps", schema: .array(.string("One build step."), "How to build it.")),
    ], "A cut list.")

    public static func request(photo: Data, mimeType: String, measured: Vector3?) -> JSON {
        let message = GeminiWire.userParts([["text": .string(prompt(measured: measured))],
                                            GeminiWire.imagePart(data: photo, mimeType: mimeType)])
        return GeminiWire.jsonRequest(contents: [message], schema: responseSchema, thinkingLevel: "low")
    }

    public static func parse(_ text: String) throws -> ChatbotAnswer {
        try JSONDecoder().decode(ChatbotAnswer.self, from: Data(text.utf8))
    }

    /// Maps the chatbot's "from" kinds onto the real parts (the first unused part of that kind; a kind it uses
    /// up gets reused, and a kind the piece doesn't have stays unknown), so the validator judges it fairly.
    public static func plan(from answer: ChatbotAnswer, inventory: Inventory) -> Plan {
        var used: Set<String> = []
        let parts = answer.parts.map { part -> DraftPart in
            let candidates = inventory.parts.filter { $0.type.rawValue == part.from }
            let source = candidates.first { !used.contains($0.id) } ?? candidates.first
            if let source { used.insert(source.id) }
            return DraftPart(heightMm: part.heightMm, name: part.name, role: Role(rawValue: part.role) ?? .other,
                             sourcePartID: source?.id ?? part.from, spanMm: nil, widthMm: part.widthMm)
        }
        let draft = PlanDraft(hardware: [], newParts: parts, steps: answer.steps,
                              template: Template(rawValue: answer.template) ?? .bench)
        let laidOut = Layout.plan(from: draft, inventory: inventory, id: planID)
        return Plan(hardware: [], id: planID, newParts: laidOut.newParts, overallMm: laidOut.overallMm, scanID: inventory.scanID,
                    source: .chatbot, steps: answer.steps, template: laidOut.template)
    }
}
