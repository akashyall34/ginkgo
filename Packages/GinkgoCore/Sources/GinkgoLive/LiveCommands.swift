import Foundation
import GinkgoCore

/// `parts`: Gemini reads the photo; GinkgoCore sizes the parts from the measurement and flags what to check.
enum PartsCommand {
    static func run(_ options: LiveOptions, key: String) async throws -> Int32 {
        let inventory = try await read(options, key: key).inventory
        if let path = options.record {
            try LiveCommand.write(try JSON.from(inventory), to: path)
            LiveCommand.say("\nInventory recorded to \(path) (use it with --inventory).")
        }
        return 0
    }

    static func read(_ options: LiveOptions, key: String) async throws -> (inventory: Inventory, flags: [PartFlag]) {
        let (path, measured) = try options.requirePhoto()
        let photo = try Data(contentsOf: URL(fileURLWithPath: path))
        let body = PartsReader.request(photo: photo, mimeType: mimeType(path), measured: measured)
        LiveCommand.say("· [parts] Gemini is reading \(URL(fileURLWithPath: path).lastPathComponent)…")
        let start = Date()
        let reading = try PartsReader.parse(try await HTTP.generateText(body, apiKey: key, model: options.model))
        let scanID = "scan-" + URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let (inventory, flags) = PartsReader.inventory(from: reading, measured: measured, scanID: scanID)
        LiveCommand.say("· [parts] \(inventory.parts.count) parts in \(String(format: "%.1f", Date().timeIntervalSince(start))) s:")
        for part in inventory.parts {
            let damage = part.damaged ? ", damaged" : ""
            LiveCommand.say("    \(part.id): \(Format.mm(part.widthMm)) × \(Format.mm(part.heightMm)) mm, "
                + "\(part.material.displayName)\(damage)")
        }
        for flag in flags { LiveCommand.say("  ⚠ \(flag.message)") }
        LiveCommand.say("")
        return (inventory, flags)
    }

    static func mimeType(_ path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "webp": return "image/webp"
        default: return "image/jpeg"
        }
    }
}

/// `chatbot`: the contrast. A plain chatbot's cut list from the same photo, judged by the same validator.
enum ChatbotCommand {
    static func run(_ options: LiveOptions, key: String) async throws -> Int32 {
        guard let path = options.photo else { throw LiveOptions.Problem(description: "chatbot needs --photo PATH") }
        let inventory = try options.loadInventory()
        let photo = try Data(contentsOf: URL(fileURLWithPath: path))
        let measured = options.withDimensions ? options.measured : nil
        let variant = measured == nil ? "photo only" : "photo + correct dimensions"
        LiveCommand.say("Chatbot baseline · \(variant) · \(options.runs) runs · judged against \(inventory.parts.count) real parts\n")
        var results: [ValidationResult] = []
        var lastFailing: Plan?
        for run in 1...options.runs {
            let body = ChatbotBaseline.request(photo: photo, mimeType: PartsCommand.mimeType(path), measured: measured)
            let answer = try ChatbotBaseline.parse(try await HTTP.generateText(body, apiKey: key, model: options.model))
            let plan = ChatbotBaseline.plan(from: answer, inventory: inventory)
            let result = Validator.validate(plan: plan, inventory: inventory, limits: options.limits)
            results.append(result)
            let cuts = answer.parts.map { "\($0.name) \(Format.mm($0.widthMm))×\(Format.mm($0.heightMm)) from \($0.from)" }
            let said = cuts.isEmpty ? "no parts (\(answer.template)): \(answer.steps.joined(separator: " "))" : cuts.joined(separator: ", ")
            LiveCommand.say("\(result.passes ? "✓" : "✗") run \(run): \(said)")
            for violation in result.violations { LiveCommand.say("    ✗ \(violation.message)") }
            if !result.passes { lastFailing = plan }
        }
        LiveCommand.say("\nChatbot, \(results.count) answers: " + EvalSummary.chatbotOutcomes(results).summary)
        if let path = options.record, let lastFailing {
            try LiveCommand.write(try JSON.from(lastFailing), to: path)
            LiveCommand.say("Last failing chatbot plan recorded to \(path)")
        }
        return 0
    }
}

/// `eval`: agent runs across variants, summarised for the slide.
enum EvalCommand {
    static func run(_ options: LiveOptions, key: String) async throws -> Int32 {
        let base = try options.loadInventory()
        let file = URL(fileURLWithPath: options.inventory).deletingPathExtension().lastPathComponent
        let baseName = file == "inventory" ? "nightstand (sample data)" : file
        var variants = EvalVariant.standard(base, name: baseName)
        for path in options.also {
            variants.append(EvalVariant(name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
                                        inventory: try options.loadInventory(path)))
        }
        LiveCommand.say("Eval · \(variants.count) variants × \(options.runs) runs · \(options.model)\n")
        var runs: [EvalRun] = []
        for variant in variants {
            for number in 1...options.runs {
                var run = await LiveCommand.agent(inventory: variant.inventory, limits: variant.limits, options: options,
                                                  key: key) { _ in }
                run.variant = variant.name
                runs.append(run)
                let result: String
                switch run.outcome {
                case .accepted: result = EvalSummary.acceptedFirstTry(run.outcome) ? "accepted first try" : "accepted after repair"
                case let .fallback(plan, _, _, reason):
                    result = "fallback (\(reason)); \(plan == nil ? "honest no" : "safe plan shown")"
                }
                LiveCommand.say("\(variant.name) #\(number): \(result), \(String(format: "%.1f", run.seconds)) s, \(run.calls) calls")
            }
        }
        let table = EvalSummary.markdown(EvalSummary.rows(runs))
        LiveCommand.say("\n" + table)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: options.out).deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try table.write(toFile: options.out, atomically: true, encoding: .utf8)
        LiveCommand.say("\nWritten to \(options.out)")
        return 0
    }
}
