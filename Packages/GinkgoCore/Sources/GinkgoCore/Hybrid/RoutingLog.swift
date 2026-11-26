import Foundation

/// What the validator said about the answer to one request.
public enum ValidatorVerdict: String, Sendable, Codable, CaseIterable {
    case passed
    case failed
    /// Nothing to validate (for example a parts list), or the request failed before a plan came back.
    case notRun = "not_run"
}

/// One AI request: what it was, where it ran and why, how long it took, and whether its plan passed.
public struct RoutingEntry: Sendable, Codable, Equatable {
    public var task: AITask
    public var venue: Venue
    public var reason: RouteReason
    /// The model that answered, as the response reports it, for example
    /// "apple-foundation-models-system-language-model", "gemini-3.8-flash" or "rule-based".
    public var model: String
    public var durationMs: Int
    public var verdict: ValidatorVerdict
    public var date: Date

    public init(task: AITask, venue: Venue, reason: RouteReason, model: String, durationMs: Int,
                verdict: ValidatorVerdict, date: Date) {
        self.task = task
        self.venue = venue
        self.reason = reason
        self.model = model
        self.durationMs = durationMs
        self.verdict = verdict
        self.date = date
    }
}

/// Totals for one venue. Every run counts, failures included.
public struct VenueSummary: Sendable, Equatable {
    public var runs: Int
    public var passed: Int
    public var failed: Int
    /// passed / (passed + failed); nil when nothing was validated.
    public var passRate: Double?
    /// Median duration of every run; nil when there are none.
    public var medianMs: Double?
}

/// Every routed request, in order. Saved as JSON Lines (one entry per line) so raw logs
/// can be kept as evidence and read back.
public struct RoutingLog: Sendable, Equatable {
    public private(set) var entries: [RoutingEntry] = []

    public init(entries: [RoutingEntry] = []) {
        self.entries = entries
    }

    public mutating func record(_ entry: RoutingEntry) {
        entries.append(entry)
    }

    public func summary(for venue: Venue, task: AITask? = nil) -> VenueSummary {
        let runs = entries.filter { $0.venue == venue && (task == nil || $0.task == task) }
        let passed = runs.filter { $0.verdict == .passed }.count
        let failed = runs.filter { $0.verdict == .failed }.count
        let validated = passed + failed
        return VenueSummary(runs: runs.count, passed: passed, failed: failed,
                            passRate: validated == 0 ? nil : Double(passed) / Double(validated),
                            medianMs: Self.median(runs.map(\.durationMs)))
    }

    static func median(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) { return Double(sorted[middle - 1] + sorted[middle]) / 2 }
        return Double(sorted[middle])
    }

    // MARK: - JSON Lines

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func jsonLines() throws -> String {
        let encoder = Self.encoder()
        return try entries.map { entry in
            // JSONEncoder always writes valid UTF-8, so the lossless conversion is exact.
            // swiftlint:disable:next optional_data_string_conversion
            String(decoding: try encoder.encode(entry), as: UTF8.self)
        }.joined(separator: "\n")
    }

    /// Reads JSON Lines back. Blank lines are skipped; a malformed line throws, so a corrupt log is never
    /// silently shortened.
    public static func parse(jsonLines text: String) throws -> RoutingLog {
        let decoder = decoder()
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.allSatisfy(\.isWhitespace) }
        return RoutingLog(entries: try lines.map { try decoder.decode(RoutingEntry.self, from: Data($0.utf8)) })
    }
}
