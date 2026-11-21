import Foundation
import GinkgoCore

/// ginkgo-live: the real Gemini pipeline from the command line. All logic lives in GinkgoCore (tested);
/// this file only reads options, calls it and prints. Exit codes: 0 = accepted / done, 2 = fallback, 1 = error.
enum LiveCommand {
    static let usage = """
        Usage: ginkgo-live <command> [options]
          plan       Gemini agent → validated plan (from --inventory, or from --photo through the parts reader)
          parts      Gemini reads --photo → parts sized by code from --width/--height/--depth (mm) → flags to check
          chatbot    a plain chatbot's cut list from --photo, judged by the same validator (--runs, --with-dimensions)
          eval       agent runs on --inventory's standard variants (+ --also a.json,b.json) → markdown table (--out)
        Options:
          --inventory PATH    inventory JSON (default examples/inventory.json)
          --photo PATH        a photo of the furniture, with --width W --height H --depth D in mm
          --request TEXT      what to build (default "Make a bench.")
          --limits TEXT       size limits in words, for example "no wider than 42 cm"
          --max-width MM      size limits in mm (also --max-height, --max-depth)
          --max-turns N       model replies allowed (default 6)    --timeout SECONDS   agent time limit (default 25)
          --runs N            runs for chatbot and eval (default 2) --model ID          (default gemini-3.8-flash)
          --record PATH       plan: trace + plan JSON; parts: inventory JSON; chatbot: the last failing plan
          --no-thinking       leave out thinkingConfig
        Needs GEMINI_API_KEY in the environment (. ~/.ginkgo.env).
        """

    static func run(_ arguments: [String]) async -> Int32 {
        let words = Array(arguments.dropFirst())
        guard let command = words.first, ["plan", "parts", "chatbot", "eval"].contains(command) else {
            say(usage)
            return 1
        }
        do {
            let options = try LiveOptions(Array(words.dropFirst()))
            guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty else {
                throw LiveOptions.Problem(description: "GEMINI_API_KEY is not set. Run: . ~/.ginkgo.env")
            }
            switch command {
            case "parts": return try await PartsCommand.run(options, key: key)
            case "chatbot": return try await ChatbotCommand.run(options, key: key)
            case "eval": return try await EvalCommand.run(options, key: key)
            default: return try await plan(options, key: key)
            }
        } catch {
            say("error: \(error)\n\n\(usage)")
            return 1
        }
    }

    static func plan(_ options: LiveOptions, key: String) async throws -> Int32 {
        let inventory = options.photo == nil ? try options.loadInventory() : try await PartsCommand.read(options, key: key).inventory
        say("Ginkgo agent · \(options.model) · \(inventory.parts.count) parts · \"\(options.request)\"\n")
        let run = await agent(inventory: inventory, limits: options.limits, options: options, key: key) { say(line(for: $0)) }
        report(run.outcome, seconds: run.seconds, calls: run.calls)
        if let path = options.record {
            try record(run.outcome, to: path, model: options.model, seconds: run.seconds)
            say("Recorded to \(path)")
        }
        if case .accepted = run.outcome { return 0 }
        return 2
    }

    /// One agent run, timed, with the number of Gemini calls.
    static func agent(inventory: Inventory, limits: SizeLimits?, options: LiveOptions, key: String,
                      onStep: @escaping @Sendable (AgentStep) -> Void) async -> EvalRun {
        let model = GeminiRESTModel(apiKey: key, model: options.model, thinkingLevel: options.thinking ? "low" : nil)
        let agent = PlanAgent(model: model, maxTurns: options.maxTurns, timeout: .seconds(options.timeout))
        let start = Date()
        let outcome = await agent.run(inventory: inventory, limits: limits, request: options.request, onStep: onStep)
        return EvalRun(variant: "", outcome: outcome, seconds: Date().timeIntervalSince(start), calls: await model.counter.count)
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
            say("Sag: \(sag.isEmpty ? "nothing load-bearing" : sag.joined(separator: "; "))")
            say("Verify first: \(verify.joined(separator: ", "))")
        } else {
            say("\nNo safe plan could be made from these parts. That's the honest answer, not a failure.")
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
        try write(document, to: path)
    }

    static func write(_ document: JSON, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (pretty(document) ?? document.encodedString()).write(to: url, atomically: true, encoding: .utf8)
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
