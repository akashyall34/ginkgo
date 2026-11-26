import FoundationModels

/// The one place the app talks to Apple's on-device model. It needs the real model, so unit tests can't run it:
/// the repair loop around it is tested with a scripted model, and this call is exercised by the on-device planning
/// runs on the iPhone (docs/phone-day.md).
@available(iOS 26.0, *)
enum AppleModelSession {
    /// A model call that answers each prompt in one conversation, with the tools Ginkgo's checks sit behind.
    static func responder(tools: [PlannerTool], instructions: String) -> (String) async throws -> Void {
        let session = LanguageModelSession(model: SystemLanguageModel.default, tools: tools, instructions: instructions)
        return { prompt in _ = try await session.respond(to: prompt) }
    }
}
