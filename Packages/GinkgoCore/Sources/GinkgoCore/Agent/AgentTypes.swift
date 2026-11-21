import Foundation

// Neutral types, so the same agent loop runs on Firebase (the app) and on the REST API (the CLI).

/// One named parameter of a tool or object.
public struct ParamProperty: Sendable, Equatable {
    public var name: String
    public var schema: ParamSchema
    public var required: Bool

    public init(name: String, schema: ParamSchema, required: Bool = true) {
        self.name = name
        self.schema = schema
        self.required = required
    }
}

/// A tool parameter's type. The String is the description the model reads.
public indirect enum ParamSchema: Sendable, Equatable {
    case string(String)
    case number(String)
    case integer(String)
    case boolean(String)
    case enumeration([String], String)
    case array(ParamSchema, String)
    case object([ParamProperty], String)
}

/// A tool the model may call.
public struct ToolSpec: Sendable, Equatable {
    public var name: String
    public var description: String
    public var parameters: ParamSchema

    public init(name: String, description: String, parameters: ParamSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// A call the model made.
public struct ToolCall: Sendable, Equatable {
    public var name: String
    public var args: JSON

    public init(name: String, args: JSON) {
        self.name = name
        self.args = args
    }
}

/// Our answer to one call. `response` is always a JSON object.
public struct ToolResult: Sendable, Equatable {
    public var name: String
    public var response: JSON

    public init(name: String, response: JSON) {
        self.name = name
        self.response = response
    }
}

/// One reply from the model: tool calls, or text when it makes none.
public struct ModelTurn: Sendable, Equatable {
    public var calls: [ToolCall]
    public var text: String?

    public init(calls: [ToolCall], text: String? = nil) {
        self.calls = calls
        self.text = text
    }
}

/// One conversation with the model.
public protocol AgentSession: Sendable {
    func send(text: String) async throws -> ModelTurn
    /// Results go back in the same order as the calls they answer.
    func send(results: [ToolResult]) async throws -> ModelTurn
}

/// A model that can start conversations with a system prompt and tools.
public protocol AgentModel: Sendable {
    func startSession(system: String, tools: [ToolSpec]) async throws -> any AgentSession
}
