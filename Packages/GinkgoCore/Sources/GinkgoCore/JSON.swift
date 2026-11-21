import Foundation

/// A small, Sendable JSON value. Used for tool arguments, tool results and the Gemini wire format.
public enum JSON: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object([String: JSON])

    /// Decodes in a fixed order (null, Bool, Double, String, array, object), so `true` stays `.bool` and `1` stays `.number`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSON].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSON].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a JSON value")
        }
    }

    /// Non-finite numbers (NaN, infinity) have no JSON form, so they encode as null instead of failing.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): if value.isFinite { try container.encode(value) } else { try container.encodeNil() }
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

// MARK: - Reading values

public extension JSON {
    /// The value for `key` when this is an object; nil otherwise.
    subscript(key: String) -> JSON? {
        objectValue?[key]
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var arrayValue: [JSON]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var objectValue: [String: JSON]? {
        if case let .object(value) = self { return value }
        return nil
    }
}

// MARK: - Converting to and from Codable types

public extension JSON {
    /// Converts any Encodable value (for example a `Plan`) into JSON.
    static func from<T: Encodable>(_ value: T) throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: JSONEncoder().encode(value))
    }

    /// Parses JSON text. Throws on malformed input.
    static func parse(_ data: Data) throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: data)
    }

    /// Converts this JSON into a Decodable type. Throws when the shape doesn't match.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: encodedData())
    }

    /// The JSON text with sorted keys, so the same value always gives the same bytes.
    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// The JSON text with sorted keys, for tests and logs.
    func encodedString() -> String {
        (try? encodedData()).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    }
}

// MARK: - Literals, so tests and tool results read like JSON

extension JSON: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSON...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object(Dictionary(elements) { _, last in last })
    }
}
