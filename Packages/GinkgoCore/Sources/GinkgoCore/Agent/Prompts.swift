import Foundation

/// What the planner agent is told. Tune these with the live CLI, never the validator.
public enum Prompts {
    /// The rules, then the materials table generated from `MaterialCatalog` (so the prompt and the validator agree).
    public static let plannerSystem = plannerRules + "\nMaterials (from Ginkgo's tested table):\n" + MaterialCatalog.promptLines

    static let plannerRules = """
        You are Ginkgo's furniture-reuse engineer. You turn the parts of one old piece of furniture into a new build.
        Furniture is not only wood: plastic carts and cardboard boxes count too, and are reused whole.
        Rules:
        - Use only parts from the inventory, by their id. Never invent parts or change their sizes.
        - Templates: "bench" (a seat panel on two upright supports) or "bookshelf" (two upright sides, shelves between them).
          Only solid_wood and plywood may be cut. Parts of particleboard_mdf, plastic or cardboard are reused whole;
          if no usable part can be cut, use "no_cut".
        - Never use a part marked damaged. Avoid keep-out areas (screw holes, damage); the tools handle them.
        - Sizes are millimetres. Our tools add saw and measurement margins themselves; never add margins yourself.
        - Roles: seat, shelf, side, support, back, other. Give span_mm for every seat and shelf (the unsupported length).
        - A good bench seat height is about 400 to 450 mm.
        - Supports and sides must be flat boards at least 150 mm wide, or the build tips over. Legs and rails are not supports.
        Process, in as few turns as possible:
        1. Call check_fit once with ALL planned parts, and check_sag once with all seats and shelves (both in the same turn).
        2. If something fails, change the design (another source part, rotate, smaller size, other template). Never ignore a failure.
        3. Call submit_plan with the full plan. If it is rejected, fix exactly what the violations say and submit again.
        Every call needs a one-sentence reason a non-expert understands. Steps: 3 to 6 short imperative sentences. Stop after acceptance.
        """

    /// Sent once when the model answers with text instead of tool calls.
    public static let nudge = "You must call check_fit, check_sag and submit_plan. Continue."

    public static let defaultRequest = "Make a bench."

    /// The request, the size limits and the inventory as JSON (sorted keys, so the same input gives the same prompt).
    public static func plannerUser(inventory: Inventory, limits: SizeLimits?, request: String) -> String {
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        let inventoryJSON = (try? JSON.from(inventory))?.encodedString() ?? "{}"
        return """
            Request: \(trimmed.isEmpty ? defaultRequest : trimmed)
            Size limits: \(describe(limits))
            Inventory (sizes in mm):
            \(inventoryJSON)
            """
    }

    static func describe(_ limits: SizeLimits?) -> String {
        guard let limits else { return "none." }
        let parts = [("width", limits.maxWidthMm), ("height", limits.maxHeightMm), ("depth", limits.maxDepthMm)]
            .compactMap { name, value in value.map { "max \(name) \(Format.mm($0)) mm" } }
        return parts.isEmpty ? "none." : parts.joined(separator: ", ") + "."
    }
}
