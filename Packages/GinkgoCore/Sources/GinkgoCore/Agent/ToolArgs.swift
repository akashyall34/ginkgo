import Foundation

/// Bad tool arguments from the model. Goes back to the model as `{"error": message}`, never a crash.
struct ToolInputError: Error, Equatable {
    var message: String

    init(_ message: String) {
        self.message = message
    }
}

/// Reading tool arguments with plain error messages, for example `placements[1].width_mm must be a number`.
extension JSON {
    func field(_ key: String, in context: String) throws -> JSON {
        guard objectValue != nil else { throw ToolInputError("\(context.isEmpty ? "the arguments" : context) must be an object") }
        guard let value = self[key], value != .null else { throw ToolInputError("\(label(key, context)) is missing") }
        return value
    }

    func string(_ key: String, in context: String = "") throws -> String {
        guard let value = try field(key, in: context).stringValue else {
            throw ToolInputError("\(label(key, context)) must be text")
        }
        return value
    }

    func number(_ key: String, in context: String = "") throws -> Double {
        guard let value = try field(key, in: context).numberValue, value.isFinite else {
            throw ToolInputError("\(label(key, context)) must be a number")
        }
        return value
    }

    func list(_ key: String, in context: String = "") throws -> [JSON] {
        guard let value = try field(key, in: context).arrayValue else {
            throw ToolInputError("\(label(key, context)) must be a list")
        }
        guard !value.isEmpty else { throw ToolInputError("\(label(key, context)) is empty") }
        return value
    }

    private func label(_ key: String, _ context: String) -> String {
        context.isEmpty ? key : "\(context).\(key)"
    }
}

enum DecodingMessage {
    /// A short, readable description of why JSON didn't match a model type.
    static func describe(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return "\(error)" }
        switch error {
        case let .keyNotFound(key, context): return "\(path(context.codingPath + [key])) is missing"
        case let .typeMismatch(_, context): return "\(path(context.codingPath)) has the wrong type"
        case let .valueNotFound(_, context): return "\(path(context.codingPath)) is missing"
        case let .dataCorrupted(context): return "\(path(context.codingPath)) has a value that isn't allowed"
        @unknown default: return "doesn't match the expected shape"
        }
    }

    /// "new_parts[0].role"
    static func path(_ keys: [CodingKey]) -> String {
        let text = keys.reduce("") { text, key in
            if let index = key.intValue { return text + "[\(index)]" }
            return text.isEmpty ? key.stringValue : text + "." + key.stringValue
        }
        return text.isEmpty ? "the plan" : text
    }
}
