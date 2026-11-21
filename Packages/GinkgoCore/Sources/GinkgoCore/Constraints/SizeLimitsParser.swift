import Foundation

/// Reads size limits from plain words, offline and deterministically: "no wider than 42 cm",
/// "under 1.5 ft wide and 45 cm tall", "max depth 300". No AI is needed to read a number.
public enum SizeLimitsParser {
    /// Millimetres per unit. A number with no unit counts as centimetres below 100, millimetres from 100 up.
    static let units: [(names: [String], mm: Double)] = [
        (["millimeters", "millimetres", "millimeter", "millimetre", "mm"], 1),
        (["centimeters", "centimetres", "centimeter", "centimetre", "cm"], 10),
        (["meters", "metres", "meter", "metre", "m"], 1000),
        (["inches", "inch", "in", "\""], 25.4),
        (["feet", "foot", "ft", "'"], 304.8),
    ]

    static let words: [(dimension: String, stems: [String])] = [
        ("width", ["wide", "width", "across", "long", "length"]),
        ("height", ["tall", "high", "height"]),
        ("depth", ["deep", "depth"]),
    ]

    /// The limits found, or nil when the text has none. The smallest value wins when a size is given twice.
    public static func parse(_ text: String) -> SizeLimits? {
        var found: [String: Double] = [:]
        for clause in clauses(text.lowercased()) {
            guard let dimension = dimension(in: clause), let value = millimetres(in: clause), value > 0 else { continue }
            found[dimension] = min(found[dimension] ?? .infinity, value)
        }
        guard !found.isEmpty else { return nil }
        return SizeLimits(maxDepthMm: found["depth"], maxHeightMm: found["height"], maxWidthMm: found["width"])
    }

    /// "42 cm wide and 45 cm tall, max depth 30" → three clauses.
    static func clauses(_ text: String) -> [String] {
        text.replacingOccurrences(of: " and ", with: ",").replacingOccurrences(of: ";", with: ",")
            .split(separator: ",").map(String.init)
    }

    static func dimension(in clause: String) -> String? {
        let tokens = clause.split { !$0.isLetter }.map(String.init)
        return words.first { entry in tokens.contains { token in entry.stems.contains { token.hasPrefix($0) } } }?.dimension
    }

    /// The first number in the clause, converted to mm by its unit.
    static func millimetres(in clause: String) -> Double? {
        let number = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*([a-z]+|"|')?"#)
        let range = NSRange(clause.startIndex..., in: clause)
        guard let match = number?.firstMatch(in: clause, range: range),
              let numberRange = Range(match.range(at: 1), in: clause),
              let value = Double(clause[numberRange]) else { return nil }
        let unitText = Range(match.range(at: 2), in: clause).map { String(clause[$0]) } ?? ""
        if let unit = units.first(where: { $0.names.contains(unitText) }) { return value * unit.mm }
        return value < 100 ? value * 10 : value
    }
}
