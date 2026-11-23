import Foundation
import GinkgoCore

/// Keeps every routed AI request on the phone as JSON Lines (Documents/routing-log.jsonl): the raw evidence of
/// where each plan was made, how long it took, and whether it passed. Nothing leaves the device.
struct RoutingLogStore {
    let url: URL

    static func standard() -> RoutingLogStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return RoutingLogStore(url: documents.appendingPathComponent("routing-log.jsonl"))
    }

    func append(_ entries: [RoutingEntry]) throws {
        guard !entries.isEmpty else { return }
        var log = try load()
        entries.forEach { log.record($0) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((try log.jsonLines() + "\n").utf8).write(to: url, options: .atomic)
    }

    /// Everything recorded so far; a missing file is an empty log.
    func load() throws -> RoutingLog {
        guard FileManager.default.fileExists(atPath: url.path) else { return RoutingLog() }
        // A damaged log throws instead of reading as empty, so an append never overwrites the evidence.
        guard let text = String(bytes: try Data(contentsOf: url), encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return try RoutingLog.parse(jsonLines: text)
    }
}
