import Foundation

/// Gemini returned nothing usable.
public enum GeminiWireError: Error, Equatable, CustomStringConvertible {
    /// No candidate, content or parts; carries the finish or block reason (for example "SAFETY").
    case blocked(String)

    public var description: String {
        switch self {
        case let .blocked(reason): return "Gemini returned no answer (\(reason))"
        }
    }
}

/// The Gemini generateContent wire format, as pure functions on JSON so every rule is tested.
public enum GeminiWire {
    /// The full request: system instruction, conversation, tool declarations and thinking setting.
    public static func requestBody(system: String, tools: [ToolSpec], contents: [JSON], thinkingLevel: String?) -> JSON {
        var body: [String: JSON] = [
            "systemInstruction": ["parts": [["text": .string(system)]]],
            "contents": .array(contents),
            "tools": [["functionDeclarations": .array(tools.map(declaration))]],
        ]
        if let thinkingLevel {
            body["generationConfig"] = ["thinkingConfig": ["thinkingLevel": .string(thinkingLevel)]]
        }
        return .object(body)
    }

    public static func declaration(_ spec: ToolSpec) -> JSON {
        ["name": .string(spec.name), "description": .string(spec.description), "parameters": schema(spec.parameters)]
    }

    /// Our parameter types as Gemini's OpenAPI subset, with uppercase type names.
    public static func schema(_ parameter: ParamSchema) -> JSON {
        switch parameter {
        case let .string(description): return ["type": "STRING", "description": .string(description)]
        case let .number(description): return ["type": "NUMBER", "description": .string(description)]
        case let .integer(description): return ["type": "INTEGER", "description": .string(description)]
        case let .boolean(description): return ["type": "BOOLEAN", "description": .string(description)]
        case let .enumeration(values, description):
            return ["type": "STRING", "enum": .array(values.map(JSON.string)), "description": .string(description)]
        case let .array(items, description):
            return ["type": "ARRAY", "items": schema(items), "description": .string(description)]
        case let .object(properties, description):
            let fields = Dictionary(properties.map { ($0.name, schema($0.schema)) }, uniquingKeysWith: { first, _ in first })
            var object: [String: JSON] = ["type": "OBJECT", "description": .string(description), "properties": .object(fields)]
            let required = properties.filter(\.required).map { JSON.string($0.name) }
            if !required.isEmpty { object["required"] = .array(required) }
            return .object(object)
        }
    }

    public static func userText(_ text: String) -> JSON {
        ["role": "user", "parts": [["text": .string(text)]]]
    }

    /// One user message holding every result, in call order. A call's `id` is echoed back when Gemini sent one.
    public static func functionResponses(_ results: [ToolResult], ids: [String?] = []) -> JSON {
        let parts = results.enumerated().map { index, result -> JSON in
            var response: [String: JSON] = ["name": .string(result.name), "response": result.response]
            if index < ids.count, let id = ids[index] { response["id"] = .string(id) }
            return ["functionResponse": .object(response)]
        }
        return ["role": "user", "parts": .array(parts)]
    }

    /// Reads a generateContent response. `modelContent` is `candidates[0].content` exactly as received:
    /// it must go back into the conversation untouched, because Gemini 3 checks its thought signatures.
    public static func parse(response: JSON) throws -> (modelContent: JSON, turn: ModelTurn) {
        guard let candidate = response["candidates"]?.arrayValue?.first else {
            throw GeminiWireError.blocked(response["promptFeedback"]?["blockReason"]?.stringValue ?? "no candidates")
        }
        guard let content = candidate["content"], let parts = content["parts"]?.arrayValue else {
            throw GeminiWireError.blocked(candidate["finishReason"]?.stringValue ?? "no content")
        }
        let calls = parts.compactMap { part in
            part["functionCall"].map { call in
                ToolCall(name: call["name"]?.stringValue ?? "", args: call["args"] ?? [:])
            }
        }
        let texts = parts.filter { $0["thought"] != true }.compactMap { $0["text"]?.stringValue }
        return (content, ModelTurn(calls: calls, text: texts.isEmpty ? nil : texts.joined()))
    }

    // MARK: - One-shot JSON calls with images (the parts reader, the chatbot baseline)

    /// A photo inside a message, sent inline as base64.
    public static func imagePart(data: Data, mimeType: String) -> JSON {
        ["inlineData": ["mimeType": .string(mimeType), "data": .string(data.base64EncodedString())]]
    }

    /// One user message made of several parts, for example text and a photo.
    public static func userParts(_ parts: [JSON]) -> JSON {
        ["role": "user", "parts": .array(parts)]
    }

    /// A request whose answer must be JSON matching `schema` (Gemini's structured output). No tools.
    public static func jsonRequest(contents: [JSON], schema output: ParamSchema, thinkingLevel: String?) -> JSON {
        var config: [String: JSON] = ["responseMimeType": "application/json", "responseSchema": schema(output)]
        if let thinkingLevel { config["thinkingConfig"] = ["thinkingLevel": .string(thinkingLevel)] }
        return ["contents": .array(contents), "generationConfig": .object(config)]
    }

    /// The `id` of each function call in a model message, in order (nil when Gemini sent none).
    public static func callIDs(in modelContent: JSON) -> [String?] {
        (modelContent["parts"]?.arrayValue ?? []).compactMap { part in
            part["functionCall"].map { $0["id"]?.stringValue }
        }
    }
}
