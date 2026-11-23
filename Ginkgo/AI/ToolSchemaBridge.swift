import FoundationModels
import GinkgoCore

/// Converts Ginkgo's tool definitions (GinkgoCore's neutral `ParamSchema`, also used for Gemini) into Apple
/// Foundation Models schemas, so one set of tool definitions drives both the on-device and the cloud model.
@available(iOS 26.0, *)
enum ToolSchemaBridge {
    static func schema(for spec: ToolSpec) throws -> GenerationSchema {
        try GenerationSchema(root: dynamic(spec.parameters, name: spec.name), dependencies: [])
    }

    /// `name` is the path from the tool to this value; Foundation Models needs a name for every object and enum.
    static func dynamic(_ schema: ParamSchema, name: String) -> DynamicGenerationSchema {
        switch schema {
        case .string: return DynamicGenerationSchema(type: String.self)
        case .number: return DynamicGenerationSchema(type: Double.self)
        case .integer: return DynamicGenerationSchema(type: Int.self)
        case .boolean: return DynamicGenerationSchema(type: Bool.self)
        case let .enumeration(values, description):
            return DynamicGenerationSchema(name: name, description: description, anyOf: values)
        case let .array(item, _):
            return DynamicGenerationSchema(arrayOf: dynamic(item, name: name + "_item"))
        case let .object(properties, description):
            return DynamicGenerationSchema(name: name, description: description, properties: properties.map {
                DynamicGenerationSchema.Property(name: $0.name, description: Self.description(of: $0.schema),
                                                 schema: dynamic($0.schema, name: name + "_" + $0.name),
                                                 isOptional: !$0.required)
            })
        }
    }

    static func description(of schema: ParamSchema) -> String {
        switch schema {
        case let .string(text), let .number(text), let .integer(text), let .boolean(text),
             let .enumeration(_, text), let .array(_, text), let .object(_, text):
            return text
        }
    }
}
