import FirebaseAILogic
import GinkgoCore

/// Converts between Vivek's agent types (GinkgoCore) and Firebase AI Logic's, so his PlanAgent can run
/// through Firebase in the app. Pure functions; the network session that uses them is in GeminiAgentModel.
enum AgentBridge {
    static func firebase(_ json: GinkgoCore.JSON) -> JSONValue {
        switch json {
        case .null: return .null
        case .bool(let value): return .bool(value)
        case .number(let value): return .number(value)
        case .string(let value): return .string(value)
        case .array(let values): return .array(values.map(firebase))
        case .object(let values): return .object(values.mapValues(firebase))
        }
    }

    static func ginkgo(_ value: JSONValue) -> GinkgoCore.JSON {
        switch value {
        case .null: return .null
        case .bool(let value): return .bool(value)
        case .number(let value): return .number(value)
        case .string(let value): return .string(value)
        case .array(let values): return .array(values.map(ginkgo))
        case .object(let values): return .object(values.mapValues(ginkgo))
        }
    }

    /// A tool result's response as a Firebase JSON object (Gemini requires an object).
    static func object(_ json: GinkgoCore.JSON) -> JSONObject {
        if case .object(let values) = json { return values.mapValues(firebase) }
        return ["result": firebase(json)]
    }

    /// The tool's top-level parameters, required and optional, for a Firebase function declaration.
    static func parameters(of spec: ToolSpec) -> (properties: [String: Schema], optional: [String]) {
        guard case .object(let properties, _) = spec.parameters else { return ([:], []) }
        return (Dictionary(uniqueKeysWithValues: properties.map { ($0.name, GeminiSchema.firebase($0.schema)) }),
                properties.filter { !$0.required }.map(\.name))
    }

    static func declaration(_ spec: ToolSpec) -> FunctionDeclaration {
        let parameters = parameters(of: spec)
        return FunctionDeclaration(name: spec.name, description: spec.description, parameters: parameters.properties,
                                   optionalParameters: parameters.optional)
    }

    static func turn(_ calls: [FunctionCallPart], text: String?) -> ModelTurn {
        ModelTurn(calls: calls.map { ToolCall(name: $0.name, args: .object($0.args.mapValues(ginkgo))) },
                  text: text)
    }
}
