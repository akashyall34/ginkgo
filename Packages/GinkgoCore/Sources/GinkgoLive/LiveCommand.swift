import Foundation
import GinkgoCore

/// `ginkgo-live plan`: runs the real Gemini agent on an inventory and prints the trace as it happens.
/// Exit codes: 0 = accepted, 2 = fallback, 1 = usage or setup error.
enum LiveCommand {
    static let usage = """
        Usage: ginkgo-live plan [options]
          --inventory PATH    inventory JSON (default examples/inventory.json)
          --request TEXT      what to build (default "Make a bench.")
          --max-width MM      size limits (also --max-height, --max-depth)
          --max-turns N       model replies allowed (default 6)
          --model ID          Gemini model (default gemini-3.8-flash)
          --timeout SECONDS   whole-run time limit (default 25)
          --record PATH       write the trace and plan as JSON, for demo fixtures
          --no-thinking       leave out thinkingConfig
        Needs GEMINI_API_KEY in the environment (. ~/.ginkgo.env).
        """

    static func run(_ arguments: [String]) async -> Int32 {
        let words = Array(arguments.dropFirst())
        guard words.first == "plan" else {
            say(usage)
            return 1
        }
        let options: LiveOptions
        let inventory: Inventory
        do {
            options = try LiveOptions(Array(words.dropFirst()))
            inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: options.inventory)))
        } catch {
            say("error: \(error)\n\n\(usage)")
            return 1
        }
        guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty else {
            say("error: GEMINI_API_KEY is not set. Run: . ~/.ginkgo.env")
            return 1
        }
        let model = GeminiRESTModel(apiKey: key, model: options.model, thinkingLevel: options.thinking ? "low" : nil)
        let agent = PlanAgent(model: model, maxTurns: options.maxTurns, timeout: .seconds(options.timeout))
        say("Ginkgo agent · \(options.model) · \(inventory.parts.count) parts · \"\(options.request)\"\n")

        let start = Date()
        let outcome = await agent.run(inventory: inventory, limits: options.limits, request: options.request) { step in
            say(line(for: step))
        }
        let seconds = Date().timeIntervalSince(start)
        let calls = await model.counter.count
        report(outcome, seconds: seconds, calls: calls)
        if let path = options.record {
            do {
                try record(outcome, to: path, model: options.model, seconds: seconds)
                say("Recorded to \(path)")
            } catch {
                say("error: couldn't write \(path): \(error)")
                return 1
            }
        }
        if case .accepted = outcome { return 0 }
        return 2
    }

    /// "✓ [check_fit] Check every cut. → seat from top: fits, 52 mm to spare"
    static func line(for step: AgentStep) -> String {
        let symbols: [Status: String] = [.pass: "✓", .fail: "✗", .accepted: "★", .info: "·", .error: "!"]
        let reason = step.reason.isEmpty ? "" : step.reason + " → "
        return "\(symbols[step.status] ?? "?") [\(step.tool.rawValue)] \(reason)\(step.summary)"
    }

    static func report(_ outcome: AgentOutcome, seconds: Double, calls: Int) {
        say("\n────────────────────────────────────────")
        switch outcome {
        case .accepted: say("Result: ACCEPTED by the validator")
        case let .fallback(_, _, _, reason): say("Result: FALLBACK (\(reason))")
        }
        if let plan = outcome.plan, let text = pretty(plan) { say("\nPlan:\n\(text)") }
        if let validation = outcome.validation {
            let sag = validation.sag.map { result in
                "\(result.newPart) \(String(format: "%.3f", result.deflectionMm)) of \(String(format: "%.2f", result.limitMm)) mm"
            }
            let verify = validation.verify.map { "\($0.sourcePartID) \($0.dimension.rawValue) \(Int($0.marginMm)) mm" }
            say("\nValidation: passes \(validation.passes), \(validation.violations.count) violations, "
                + "reuse \(validation.reusePercent)%")
            say("Sag: \(sag.joined(separator: "; "))")
            say("Verify first: \(verify.joined(separator: ", "))")
        } else {
            say("\nNo safe plan could be made.")
        }
        say("\nTime: \(String(format: "%.1f", seconds)) s · Gemini calls: \(calls) · trace steps: \(outcome.trace.count)")
    }

    static func record(_ outcome: AgentOutcome, to path: String, model: String, seconds: Double) throws {
        var reason: JSON = .null
        if case let .fallback(_, _, _, text) = outcome { reason = .string(text) }
        let accepted: Bool
        if case .accepted = outcome { accepted = true } else { accepted = false }
        let document: JSON = [
            "outcome": .string(accepted ? "accepted" : "fallback"), "reason": reason, "model": .string(model),
            "seconds": .number((seconds * 10).rounded() / 10), "trace": try JSON.from(outcome.trace),
            "plan": try outcome.plan.map { try JSON.from($0) } ?? .null,
            "validation": try outcome.validation.map { try JSON.from($0) } ?? .null,
        ]
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try document.encodedData().write(to: url)
    }

    static func pretty<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Unbuffered output, so each trace line shows up the moment it happens.
    static func say(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
}

/// The command-line options for `plan`.
struct LiveOptions {
    var inventory = "examples/inventory.json"
    var request = Prompts.defaultRequest
    var limits: SizeLimits?
    var maxTurns = 6
    var model = "gemini-3.8-flash"
    var timeout = 25
    var record: String?
    var thinking = true

    static let valued: Set<String> = [
        "--inventory", "--request", "--max-width", "--max-height", "--max-depth", "--max-turns", "--model", "--timeout", "--record",
    ]

    struct Problem: Error, CustomStringConvertible {
        var description: String
    }

    init(_ words: [String]) throws {
        var values: [String: String] = [:]
        var index = 0
        while index < words.count {
            let word = words[index]
            if word == "--no-thinking" {
                thinking = false
                index += 1
                continue
            }
            guard Self.valued.contains(word) else { throw Problem(description: "unknown option \(word)") }
            guard index + 1 < words.count else { throw Problem(description: "\(word) needs a value") }
            values[word] = words[index + 1]
            index += 2
        }
        inventory = values["--inventory"] ?? inventory
        request = values["--request"] ?? request
        model = values["--model"] ?? model
        record = values["--record"]
        maxTurns = try Self.whole(values["--max-turns"], "--max-turns") ?? maxTurns
        timeout = try Self.whole(values["--timeout"], "--timeout") ?? timeout
        let width = try Self.millimetres(values["--max-width"], "--max-width")
        let height = try Self.millimetres(values["--max-height"], "--max-height")
        let depth = try Self.millimetres(values["--max-depth"], "--max-depth")
        if width != nil || height != nil || depth != nil {
            limits = SizeLimits(maxDepthMm: depth, maxHeightMm: height, maxWidthMm: width)
        }
    }

    static func whole(_ text: String?, _ name: String) throws -> Int? {
        guard let text else { return nil }
        guard let value = Int(text), value > 0 else { throw Problem(description: "\(name) must be a whole number above 0") }
        return value
    }

    static func millimetres(_ text: String?, _ name: String) throws -> Double? {
        guard let text else { return nil }
        guard let value = Double(text), value > 0, value.isFinite else { throw Problem(description: "\(name) must be a size in mm") }
        return value
    }
}
