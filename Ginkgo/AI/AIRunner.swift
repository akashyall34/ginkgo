import Foundation

/// Runs an AI call with retries and a backup model. Google's free tier returns
/// "high demand" errors at busy times, so no single call is trusted to succeed.
///
/// For each model in order: try up to `attemptsPerModel` times, waiting longer after
/// each failure; if every attempt fails, move to the next model. If all models fail,
/// the last error is thrown so the caller can fall back (rule-based plan, demo data).
struct AIRunner: Sendable {
    var models: [String]
    var attemptsPerModel: Int
    /// Wait after failed attempt n (1-based) before the next one.
    var backoff: @Sendable (Int) -> Duration
    /// Injected so tests run instantly with a fake clock.
    var sleep: @Sendable (Duration) async throws -> Void

    /// Main model, then a lighter, faster one. Remote Config can replace the list (see `RemoteSettings`).
    static let builtInModels = ["gemini-3.8-flash", "gemini-3.5-flash-lite"]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var storedModels = builtInModels

    /// The models in use: the built-in list, or a checked one from Remote Config.
    static var models: [String] {
        get { lock.withLock { storedModels } }
        set { lock.withLock { storedModels = newValue } }
    }

    static var standard: AIRunner { AIRunner(
        // One attempt each: a slow model is better abandoned for the backup than retried (measured Nov 21:
        // overloaded requests took 40-60+ s, while 503 "high demand" errors fail fast).
        models: models,
        attemptsPerModel: 1,
        backoff: { attempt in .milliseconds(800 * attempt) },
        sleep: { try await Task.sleep(for: $0) }
    ) }

    /// The longest a full run can take if every attempt times out: every attempt's
    /// timeout plus every pause between attempts. Keeps the user's wait bounded.
    func worstCaseDuration(perAttemptTimeout: Duration) -> Duration {
        let pauses = (1..<attemptsPerModel).reduce(Duration.zero) { $0 + backoff($1) } * models.count
        return perAttemptTimeout * (models.count * attemptsPerModel) + pauses
    }

    struct Failure: Error {
        let attempts: [(model: String, error: Error)]
    }

    /// No model or no attempt to run: a setup mistake, reported like any failure so the caller falls back.
    struct Misconfigured: Error, Equatable {}

    func run<T: Sendable>(_ call: @Sendable (String) async throws -> T) async throws -> T {
        guard !models.isEmpty, attemptsPerModel > 0 else { throw Misconfigured() }
        var failures: [(model: String, error: Error)] = []
        for model in models {
            for attempt in 1...attemptsPerModel {
                try Task.checkCancellation()
                do {
                    return try await call(model)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    failures.append((model, error))
                    if attempt < attemptsPerModel { try await sleep(backoff(attempt)) }
                }
            }
        }
        throw Failure(attempts: failures)
    }
}
