import Foundation

/// The three tools the planner agent may call. Every call carries a `reason` that becomes its trace line.
public enum AgentTools {
    static let reason = ParamProperty(
        name: "reason", schema: .string("One short sentence, for a non-expert, saying why you are making this check."))

    static let roles = ["shelf", "seat", "side", "support", "back", "other"]

    public static let checkFit = ToolSpec(
        name: Tool.checkFit.rawValue,
        description: "Checks whether new parts can be cut from their source parts. Our code adds the saw and measurement "
            + "margin (8 mm per dimension) and avoids screw holes and damage. Do not add margins yourself. "
            + "Check all parts in one call.",
        parameters: .object([
            reason,
            ParamProperty(name: "placements", schema: .array(.object([
                ParamProperty(name: "new_part", schema: .string("Name of the new part, for example \"seat\".")),
                ParamProperty(name: "source_part_id", schema: .string("ID of the inventory part to cut it from.")),
                ParamProperty(name: "width_mm", schema: .number("Finished width in mm, without margins.")),
                ParamProperty(name: "height_mm", schema: .number("Finished height in mm, without margins.")),
            ], "One new part to check."), "Every new part of the design.")),
        ], "Arguments for check_fit."))

    public static let checkSag = ToolSpec(
        name: Tool.checkSag.rawValue,
        description: "Checks that seats and shelves won't bend too much under load (seat 100 kg, shelf 30 kg).",
        parameters: .object([
            reason,
            ParamProperty(name: "items", schema: .array(.object([
                ParamProperty(name: "new_part", schema: .string("Name of the seat or shelf.")),
                ParamProperty(name: "source_part_id", schema: .string("ID of the inventory part it is cut from.")),
                ParamProperty(name: "role", schema: .enumeration(["seat", "shelf"], "seat or shelf.")),
                ParamProperty(name: "span_mm", schema: .number("Unsupported length between the supports, in mm.")),
                ParamProperty(name: "depth_mm", schema: .number("Front-to-back depth of the part, in mm.")),
            ], "One seat or shelf."), "Every seat and shelf of the design.")),
        ], "Arguments for check_sag."))

    public static let submitPlan = ToolSpec(
        name: Tool.submitPlan.rawValue,
        description: "Submits the final plan. Only an accepted plan can be shown. If it's rejected, fix the design and submit again.",
        parameters: .object([
            reason,
            ParamProperty(name: "plan", schema: .object([
                ParamProperty(name: "template", schema: .enumeration(["bench", "bookshelf", "no_cut"], "The kind of build.")),
                ParamProperty(name: "new_parts", schema: .array(.object([
                    ParamProperty(name: "name", schema: .string("A unique name, for example \"seat\".")),
                    ParamProperty(name: "source_part_id", schema: .string("ID of the inventory part it comes from.")),
                    ParamProperty(name: "width_mm", schema: .number("Finished width in mm.")),
                    ParamProperty(name: "height_mm", schema: .number("Finished height in mm.")),
                    ParamProperty(name: "role", schema: .enumeration(roles, "What the part does in the build.")),
                    ParamProperty(name: "span_mm", schema: .number("Unsupported span, for seats and shelves."), required: false),
                ], "One part of the new build."), "Every part of the new build.")),
                ParamProperty(name: "steps", schema: .array(.string("One short imperative sentence."), "3 to 6 build steps.")),
                ParamProperty(name: "hardware", schema: .array(.object([
                    ParamProperty(name: "item", schema: .string("For example \"wood screw, 40 mm\".")),
                    ParamProperty(name: "quantity", schema: .integer("How many, at least 1.")),
                ], "One hardware item."), "Screws and other hardware.")),
            ], "The full plan.")),
        ], "Arguments for submit_plan."))

    public static let all = [checkFit, checkSag, submitPlan]
}
