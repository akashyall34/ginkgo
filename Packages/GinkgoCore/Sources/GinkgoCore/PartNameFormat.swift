import Foundation

public extension Format {
    /// A part's name in plain words: "leg_left" → "left leg", "drawer_front" → "drawer front", "seat" → "seat".
    static func partName(_ id: String) -> String {
        var words = id.split(separator: "_").map(String.init)
        if let last = words.last, ["left", "right"].contains(last), words.count > 1 {
            words.removeLast()
            words.insert(last, at: 0)
        }
        return words.joined(separator: " ")
    }
}

public extension String {
    /// "left leg" → "Left leg".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
