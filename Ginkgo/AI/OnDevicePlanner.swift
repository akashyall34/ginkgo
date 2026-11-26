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
        let args = try JSONDecoder().decode(JSON.self, from: Data(arguments.jsonString.utf8))
        let outcome = executor.run(ToolCall(name: spec.name, args: args), index: await recorder.count)
        await recorder.record(outcome)
        // JSONEncoder always writes valid UTF-8, so the lossless conversion is exact.
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: try JSONEncoder().encode(outcome.result.response), as: UTF8.self)
    }
}

/// Plans on this iPhone with Apple's on-device model, through the same tools and validator as the cloud.
/// A small model sometimes stops after a failed check, so the open problems are handed back for up to
/// `HybridRouter.deviceAttempts` repair rounds; after that the hybrid planner moves the job to the cloud.
@available(iOS 26.0, *)
struct OnDevicePlanner: DevicePlanning {
    static let modelName = DeviceModel.name
    /// False in offline test runs (`-noGemini`), which need the fast, predictable rule-based path.
    var enabled = true
    /// Longest a person waits for the phone before the cloud takes over. Accepted on-device plans took
    /// 21-56 s on an M4 Pro Mac (Nov 23, 5 runs); a run past this is unlikely to finish well.
    var timeLimit: Duration = .seconds(60)

    var isAvailable: Bool { enabled && SystemLanguageModel.default.isAvailable }

    func plan(inventory: Inventory, request: String,
              onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult {
        let recorder = PlanRecorder(onStep: onStep)
        let error = await Self.race(limit: timeLimit) {
            await Self.converse(inventory: inventory, request: request, recorder: recorder)
        }
        if let error { Self.log.error("On-device planning stopped: \(error, privacy: .public)") }
        return DevicePlanResult(accepted: await recorder.accepted, trace: await recorder.steps,
                                rejections: await recorder.rejections, model: Self.modelName, error: error)
    }

    static let log = Logger(subsystem: "com.akashy.ginkgo", category: "on-device")

    /// Runs `work` against the clock: whichever ends first decides. Returns why the work stopped early (its own
    /// reason, or that it took longer than `limit`), or nil when it ended normally in time.
    static func race(limit: Duration, work: @escaping @Sendable () async -> String?) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: limit)
                return Task.isCancelled ? nil : "took longer than \(limit)"
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
    }

    /// Runs the conversation; returns why it stopped early, or nil when it ended normally.
    static func converse(inventory: Inventory, request: String, recorder: PlanRecorder,
                         specs: [ToolSpec] = AgentTools.all) async -> String? {
        let executor = ToolExecutor(inventory: inventory, limits: nil)
        let tools: [PlannerTool]
        do {
            tools = try specs.map { try PlannerTool(spec: $0, executor: executor, recorder: recorder) }
        } catch {
            return "tool schema: \(error)"
        }
        return await repair(firstPrompt: Prompts.plannerUser(inventory: inventory, limits: nil, request: request),
                            recorder: recorder, respond: AppleModelSession.responder(tools: tools,
                                                                                     instructions: Prompts.plannerSystem))
    }

    /// Asks the model, and while no plan is accepted hands it the validator's last complaint, for up to
    /// `HybridRouter.deviceAttempts` repair rounds. `respond` is the model call, so the loop can be tested without
    /// the model. Returns why it stopped early, or nil when it ended normally.
    static func repair(firstPrompt: String, recorder: PlanRecorder,
                       respond: (String) async throws -> Void) async -> String? {
        var prompt = firstPrompt
        for _ in 0...HybridRouter.deviceAttempts {
            if Task.isCancelled { return "cancelled" }
            do {
                try await respond(prompt)
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

/// The model's name in the routing log.
enum DeviceModel {
    static let name = "apple-foundation-models-system-language-model"
}

/// Stands in for the on-device planner on an iOS without Apple's model (before iOS 26): never available, so the
/// hybrid planner goes straight to the cloud or the rules.
struct NoDevicePlanner: DevicePlanning {
    var isAvailable: Bool { false }

    func plan(inventory: Inventory, request: String,
              onStep: @escaping @Sendable (AgentStep) -> Void) async -> DevicePlanResult {
        DevicePlanResult(accepted: nil, trace: [], rejections: 0, model: DeviceModel.name)
    }
}
