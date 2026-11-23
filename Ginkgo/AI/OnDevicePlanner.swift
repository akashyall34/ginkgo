import Foundation
import FoundationModels
import GinkgoCore
import OSLog

/// Collects what the tools did during one planning run, across the model's tool calls.
actor PlanRecorder {
    private(set) var steps: [AgentStep] = []
    private(set) var accepted: AcceptedPlan?
    private let onStep: @Sendable (AgentStep) -> Void

    init(onStep: @escaping @Sendable (AgentStep) -> Void) { self.onStep = onStep }

    func record(_ outcome: ToolOutcome) {
        steps.append(outcome.step)
        if let plan = outcome.accepted { accepted = plan }
        onStep(outcome.step)
    }

    /// Plans the validator turned down so far: failed checks and rejected submissions.
    var rejections: Int { steps.filter { $0.status == .fail }.count }
    var count: Int { steps.count }
}

/// One of Ginkgo's three tools (check_fit, check_sag, submit_plan) as an Apple Foundation Models tool. The model
/// calls it; Ginkgo's tested code answers. Bad arguments come back as an error the model can read and fix.
@available(iOS 26.0, *)
struct PlannerTool: FoundationModels.Tool {
    let spec: ToolSpec
    let parameters: GenerationSchema
    let executor: ToolExecutor
    let recorder: PlanRecorder

    var name: String { spec.name }
    var description: String { spec.description }

    init(spec: ToolSpec, executor: ToolExecutor, recorder: PlanRecorder) throws {
        self.spec = spec
        self.parameters = try ToolSchemaBridge.schema(for: spec)
        self.executor = executor
        self.recorder = recorder
    }

    func call(arguments: GeneratedContent) async throws -> String {
        let args = (try? JSONDecoder().decode(JSON.self, from: Data(arguments.jsonString.utf8))) ?? .object([:])
        let outcome = executor.run(ToolCall(name: spec.name, args: args), index: await recorder.count)
        await recorder.record(outcome)
        return String(bytes: try JSONEncoder().encode(outcome.result.response), encoding: .utf8) ?? "{}"
    }
}

/// Plans on this iPhone with Apple's on-device model, through the same tools and validator as the cloud.
/// A small model sometimes stops after a failed check, so the open problems are handed back for up to
/// `HybridRouter.deviceAttempts` repair rounds; after that the hybrid planner moves the job to the cloud.
struct OnDevicePlanner: DevicePlanning {
    static let modelName = "apple-foundation-models-system-language-model"
    /// False in offline test runs (`-noGemini`), which need the fast, predictable rule-based path.
    var enabled = true
    /// Longest a person waits for the phone before the cloud takes over. Accepted on-device plans took
    /// 21-56 s on an M4 Pro Mac (Nov 23, 5 runs); a run past this is unlikely to finish well.
    var timeLimit: Duration = .seconds(60)

    var isAvailable: Bool {
        guard enabled, #available(iOS 26.0, *) else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    func plan(inventory: Inventory, request: String,
              onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult {
        guard #available(iOS 26.0, *) else {
            return DevicePlanResult(accepted: nil, trace: [], rejections: 0, model: Self.modelName)
        }
        let recorder = PlanRecorder(onStep: onStep)
        let limit = timeLimit
        let error = await withTaskGroup(of: String?.self) { group in
            group.addTask { await Self.converse(inventory: inventory, request: request, recorder: recorder) }
            group.addTask {
                try? await Task.sleep(for: limit)
                return Task.isCancelled ? nil : "took longer than \(limit)"
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
        if let error { Self.log.error("On-device planning stopped: \(error, privacy: .public)") }
        return DevicePlanResult(accepted: await recorder.accepted, trace: await recorder.steps,
                                rejections: await recorder.rejections, model: Self.modelName, error: error)
    }

    static let log = Logger(subsystem: "com.akashy.ginkgo", category: "on-device")

    /// Runs the conversation; returns why it stopped early, or nil when it ended normally.
    @available(iOS 26.0, *)
    private static func converse(inventory: Inventory, request: String, recorder: PlanRecorder) async -> String? {
        let executor = ToolExecutor(inventory: inventory, limits: nil)
        let tools: [PlannerTool]
        do {
            tools = try AgentTools.all.map { try PlannerTool(spec: $0, executor: executor, recorder: recorder) }
        } catch {
            return "tool schema: \(error)"
        }
        let session = LanguageModelSession(model: SystemLanguageModel.default, tools: tools,
                                           instructions: Prompts.plannerSystem)
        var prompt = Prompts.plannerUser(inventory: inventory, limits: nil, request: request)
        for _ in 0...HybridRouter.deviceAttempts {
            if Task.isCancelled { return "cancelled" }
            do {
                _ = try await session.respond(to: prompt)
            } catch {
                return "\(error)"
            }
            if await recorder.accepted != nil { return nil }
            prompt = repairPrompt(lastProblem: await recorder.steps.last { $0.status == .fail }?.summary)
        }
        return nil
    }

    /// Hands the validator's last complaint back to the model.
    static func repairPrompt(lastProblem: String?) -> String {
        "Not accepted yet. Problems: \(lastProblem ?? "No plan was submitted.") "
            + "Fix the design, then call check_fit, check_sag and submit_plan."
    }
}
