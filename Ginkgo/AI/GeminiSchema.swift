import FirebaseAILogic
import GinkgoCore

/// Vivek's schemas (GinkgoCore's ParamSchema) as Firebase AI Logic schemas, so the app asks Gemini for
/// exactly the JSON shape the package parses. Property order is kept, which helps the model.
enum GeminiSchema {
    static func firebase(_ schema: ParamSchema) -> Schema {
        switch schema {
        case .string(let about): return .string(description: about)
        case .number(let about): return .double(description: about)
        case .integer(let about): return .integer(description: about)
        case .boolean(let about): return .boolean(description: about)
        case .enumeration(let values, let about): return .enumeration(values: values, description: about)
        case .array(let items, let about): return .array(items: firebase(items), description: about)
        case .object(let properties, let about):
            return .object(
                properties: Dictionary(uniqueKeysWithValues: properties.map { ($0.name, firebase($0.schema)) }),
                optionalProperties: properties.filter { !$0.required }.map(\.name),
                propertyOrdering: properties.map(\.name),
                description: about
            )
        }
    }
}
