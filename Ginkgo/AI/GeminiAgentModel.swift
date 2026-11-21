import FirebaseAILogic
import FirebaseCore
import GinkgoCore

/// Gemini through Firebase AI Logic as the model for Vivek's PlanAgent: a chat with his system prompt
/// and tools. The key never ships in the app. Network glue; the conversions are tested in AgentBridge.
struct GeminiAgentModel: AgentModel {
    var modelName = AIRunner.standard.models[0]

    /// `-noGemini` at launch (UI tests) plans offline, exactly as with no connection.
    static var isDisabled: Bool { ProcessInfo.processInfo.arguments.contains("-noGemini") }

    func startSession(system: String, tools: [ToolSpec]) async throws -> any AgentSession {
        guard FirebaseApp.app() != nil, !Self.isDisabled else { throw GeminiError.notConfigured }
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: modelName,
            generationConfig: GenerationConfig(thinkingConfig: GeminiClient.thinking),
            tools: [.functionDeclarations(tools.map(AgentBridge.declaration))],
            systemInstruction: ModelContent(role: "system", parts: system),
            requestOptions: RequestOptions(timeout: GeminiClient.requestTimeout.seconds)
        )
        return GeminiAgentSession(chat: model.startChat())
    }
}

/// One planning conversation. Results go back in the order of the calls they answer, with their ids.
actor GeminiAgentSession: AgentSession {
    private let chat: Chat
    private var lastCallIDs: [String?] = []

    init(chat: Chat) { self.chat = chat }

    func send(text: String) async throws -> ModelTurn {
        try record(await chat.sendMessage(text))
    }

    func send(results: [ToolResult]) async throws -> ModelTurn {
        let parts: [any FirebaseAILogic.Part] = results.enumerated().map { index, result in
            FunctionResponsePart(name: result.name, response: AgentBridge.object(result.response),
                                 functionId: index < lastCallIDs.count ? lastCallIDs[index] : nil)
        }
        return try record(await chat.sendMessage([ModelContent(role: "user", parts: parts)]))
    }

    private func record(_ response: GenerateContentResponse) -> ModelTurn {
        let calls = response.functionCalls
        lastCallIDs = calls.map(\.functionId)
        return AgentBridge.turn(calls, text: calls.isEmpty ? response.text : nil)
    }
}
