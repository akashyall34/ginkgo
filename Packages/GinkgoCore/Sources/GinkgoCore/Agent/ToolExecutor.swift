import Foundation

/// A plan the validator accepted.
public struct AcceptedPlan: Sendable, Equatable {
    public var plan: Plan
    public var validation: ValidationResult

    public init(plan: Plan, validation: ValidationResult) {
        self.plan = plan
        self.validation = validation
    }
}

/// What one tool call produced: the answer for the model, the trace line for the screen, and the plan if accepted.
public struct ToolOutcome: Sendable, Equatable {
    public var result: ToolResult
    public var step: AgentStep
    public var accepted: AcceptedPlan?
}

/// Runs the model's tool calls against our tested code. Any bad input becomes `{"error": ...}`. It never crashes.
public struct ToolExecutor: Sendable {
    public static let planID = "plan-agent"
    public var inventory: Inventory
    public var limits: SizeLimits?

    public init(inventory: Inventory, limits: SizeLimits?) {
        self.inventory = inventory
        self.limits = limits
    }

    public func run(_ call: ToolCall, index: Int) -> ToolOutcome {
        let reason = call.args["reason"]?.stringValue ?? ""
        do {
            switch call.name {
            case Tool.checkFit.rawValue: return try checkFit(call.args, index: index, reason: reason)
            case Tool.checkSag.rawValue: return try checkSag(call.args, index: index, reason: reason)
            case Tool.submitPlan.rawValue: return try submitPlan(call.args, index: index, reason: reason)
            default: throw ToolInputError("There is no tool \"\(call.name)\". Use check_fit, check_sag or submit_plan.")
            }
        } catch {
            let message = (error as? ToolInputError)?.message ?? "\(error)"
            return ToolOutcome(
                result: ToolResult(name: call.name, response: ["error": .string(message)]),
                step: AgentStep(index: index, reason: reason, status: .error, summary: "error: \(message)",
                                tool: Tool(rawValue: call.name) ?? .note),
                accepted: nil)
        }
    }

    // MARK: - submit_plan

    func submitPlan(_ args: JSON, index: Int, reason: String) throws -> ToolOutcome {
        let planJSON = try args.field("plan", in: "arguments")
        let draft: PlanDraft
        do {
            draft = try planJSON.decode(PlanDraft.self)
        } catch {
            throw ToolInputError("plan: \(DecodingMessage.describe(error))")
        }
        guard !draft.newParts.isEmpty else { throw ToolInputError("plan.new_parts is empty: list every part of the build") }

        let plan = Layout.plan(from: draft, inventory: inventory, id: Self.planID)
        let validation = Validator.validate(plan: plan, inventory: inventory, limits: limits)
        let response: JSON
        let summary: String
        if validation.passes {
            response = ["accepted": true, "reuse_percent": .number(validation.reusePercent)]
            summary = "accepted by the validator: \(plan.newParts.count) parts, \(Format.mm(validation.reusePercent))% reused"
        } else {
            let messages = validation.violations.map(\.message)
            response = ["accepted": false, "violations": .array(messages.map(JSON.string))]
            let count = messages.count == 1 ? "1 problem" : "\(messages.count) problems"
            summary = "rejected, \(count): " + messages.joined(separator: " ")
        }
        return ToolOutcome(
            result: ToolResult(name: Tool.submitPlan.rawValue, response: response),
            step: AgentStep(index: index, reason: reason, status: validation.passes ? .accepted : .fail, summary: summary,
                            tool: .submitPlan),
            accepted: validation.passes ? AcceptedPlan(plan: plan, validation: validation) : nil)
    }

    // MARK: - Shared

    var partsByID: [String: Part] {
        Dictionary(inventory.parts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var validIDs: String {
        inventory.parts.map(\.id).joined(separator: ", ")
    }

    static func rounded(_ value: Double) -> JSON {
        .number((value * 1000).rounded() / 1000)
    }
}
