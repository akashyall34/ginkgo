import Foundation
import GinkgoCore

/// Turns the validator's step summaries (written for the log, with part ids like `side_left`) into short,
/// plain words for the Plan screens: one headline per step, and a line only for each thing that went wrong.
enum StepWording {
    static func headline(_ step: AgentStep) -> String {
        let items = items(step)
        let failing = items.filter { !$0.passes }.count
        switch (step.tool, step.status) {
        case (.checkFit, .pass): return items.count == 1 ? "The cut fits" : "All \(items.count) cuts fit"
        case (.checkFit, _): return failing == 1 && items.count == 1 ? "The cut doesn't fit"
            : "\(failing) of \(items.count) cuts don't fit"
        case (.checkSag, .pass): return "Strong enough"
        case (.checkSag, _): return "Too bendy"
        case (.submitPlan, .accepted): return "Plan accepted" + acceptedDetail(step.summary)
        case (.submitPlan, _): return "Plan sent back for another try"
        case (.fallback, .error): return "Gemini's connection failed, so Ginkgo planned it with its own rules."
        case (.fallback, _): return "Showing Ginkgo's own rule-based plan. It passes the validator."
        case (.note, _): return step.summary
        }
    }

    /// One line per problem, in plain words. Passing checks need no lines: the headline says it.
    static func problems(_ step: AgentStep) -> [String] {
        guard step.tool == .checkFit || step.tool == .checkSag || step.tool == .submitPlan else { return [] }
        return items(step).filter { !$0.passes }.map(\.text)
    }

    /// "Ginkgo's checks caught 3 problems before accepting a plan."
    static func story(_ trace: [AgentStep]) -> String? {
        let caught = trace.filter { $0.status == .fail }.count
        guard trace.contains(where: { $0.status == .accepted }) else { return nil }
        switch caught {
        case 0: return "Gemini's first plan passed every check."
        case 1: return "Ginkgo's checks caught 1 problem before accepting a plan."
        default: return "Ginkgo's checks caught \(caught) problems before accepting a plan."
        }
    }

    // MARK: - Parsing the log wording

    struct Item: Equatable {
        let text: String
        let passes: Bool
    }

    /// The summary's "; "-separated parts, each reworded.
    static func items(_ step: AgentStep) -> [Item] {
        guard step.tool == .checkFit || step.tool == .checkSag else {
            return step.status == .fail ? [Item(text: step.summary, passes: false)] : []
        }
        return step.summary.components(separatedBy: "; ").filter { !$0.isEmpty }.map { item($0, tool: step.tool) }
    }

    /// "support_left from side_right: 8 mm short" → "Left support from the right side: 8 mm short".
    /// "seat: bends 0.93 of 0.87 mm allowed, too much" → "Seat bends 0.93 mm; 0.87 mm allowed".
    static func item(_ raw: String, tool: Tool) -> Item {
        guard let colon = raw.range(of: ": ") else { return Item(text: raw, passes: false) }
        let subject = String(raw[..<colon.lowerBound])
        let rest = String(raw[colon.upperBound...])
        if tool == .checkSag, rest.hasPrefix("bends "), let of = rest.range(of: " of ") {
            let bend = rest[rest.index(rest.startIndex, offsetBy: 6)..<of.lowerBound]
            let allowed = rest[of.upperBound...].replacingOccurrences(of: ", too much", with: "")
            return Item(text: "\(piece(subject)) bends \(bend) mm; \(allowed)", passes: !rest.hasSuffix("too much"))
        }
        let parts = subject.components(separatedBy: " from ")
        let who = parts.count == 2 ? "\(piece(parts[0])) from the \(panel(parts[1]))" : piece(subject)
        return Item(text: "\(who): \(rest)", passes: rest.hasPrefix("fits"))
    }

    /// "support_left" → "Left support"; "seat" → "Seat".
    static func piece(_ id: String) -> String {
        let words = reordered(id)
        return words.prefix(1).capitalized + words.dropFirst()
    }

    /// "side_left" → "left side"; "drawer_front" → "drawer front".
    static func panel(_ id: String) -> String { reordered(id) }

    private static func reordered(_ id: String) -> String {
        var words = id.split(separator: "_").map(String.init)
        if let last = words.last, ["left", "right"].contains(last), words.count > 1 {
            words.removeLast()
            words.insert(last, at: 0)
        }
        return words.joined(separator: " ")
    }

    /// "accepted by the validator: 3 parts, 64.9% reused" → ": 3 parts, 64.9% reused".
    private static func acceptedDetail(_ summary: String) -> String {
        guard let colon = summary.range(of: ": ") else { return "" }
        return ": " + summary[colon.upperBound...]
    }
}
