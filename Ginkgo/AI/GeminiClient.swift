import FirebaseAILogic
import FirebaseCore
import Foundation

extension Duration {
    /// The duration in seconds, for APIs that take a TimeInterval.
    var seconds: TimeInterval {
        let (whole, attoseconds) = components
        return TimeInterval(whole) + TimeInterval(attoseconds) / 1e18
    }
}

enum GeminiError: Error, Equatable {
    /// GoogleService-Info.plist isn't bundled, so Firebase isn't set up.
    case notConfigured
    /// The model answered, but with no text.
    case emptyResponse
}

/// Asks Gemini (through Firebase AI Logic) for JSON that matches a schema, with the
/// retries and backup model from `AIRunner`. The key never ships in the app.
struct GeminiClient: Sendable {
    var runner: AIRunner = .standard
    /// Per-attempt limit. Firebase's default is 180 s, which made one busy-server call
    /// take over 6 minutes; with this limit a full run with fallbacks stays under a minute.
    static let requestTimeout: Duration = .seconds(25)
    /// Structured extraction and template filling don't need deep reasoning; low thinking
    /// answered where default thinking produced nothing within 60 s (measured Nov 21).
    static let thinking = ThinkingConfig(thinkingLevel: .low)

    /// Returns the model's JSON text, already constrained to `schema`.
    func json(prompt: String, schema: Schema) async throws -> String {
        guard FirebaseApp.app() != nil else { throw GeminiError.notConfigured }
        return try await runner.run { modelName in
            let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
                modelName: modelName,
                generationConfig: GenerationConfig(responseMIMEType: "application/json", responseSchema: schema,
                                                   thinkingConfig: Self.thinking),
                requestOptions: RequestOptions(timeout: Self.requestTimeout.seconds)
            )
            let response = try await model.generateContent(prompt)
            guard let text = response.text, !text.isEmpty else { throw GeminiError.emptyResponse }
            return text
        }
    }
}
