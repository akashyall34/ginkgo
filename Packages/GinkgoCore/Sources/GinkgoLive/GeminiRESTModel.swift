import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import GinkgoCore

/// A non-200 answer, with the status and the body so a 400 says what was wrong.
struct GeminiHTTPError: Error, CustomStringConvertible {
    var status: Int
    var body: String

    var description: String { "HTTP \(status): \(body)" }
}

/// Counts requests across a run, for the summary line.
actor RequestCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

/// Gemini over the REST API, for the command-line tool. The app uses Firebase instead (same agent, other adapter).
struct GeminiRESTModel: AgentModel {
    var apiKey: String
    var model: String
    var thinkingLevel: String?
    var requestTimeout: TimeInterval = 25
    let counter = RequestCounter()

    func startSession(system: String, tools: [ToolSpec]) async throws -> any AgentSession {
        GeminiRESTSession(config: self, system: system, tools: tools)
    }
}

/// One conversation. Gemini's replies are appended exactly as received, so thought signatures survive.
actor GeminiRESTSession: AgentSession {
    private let config: GeminiRESTModel
    private let system: String
    private let tools: [ToolSpec]
    private var contents: [JSON] = []
    private var lastCallIDs: [String?] = []

    init(config: GeminiRESTModel, system: String, tools: [ToolSpec]) {
        self.config = config
        self.system = system
        self.tools = tools
    }

    func send(text: String) async throws -> ModelTurn {
        contents.append(GeminiWire.userText(text))
        return try await post()
    }

    func send(results: [ToolResult]) async throws -> ModelTurn {
        contents.append(GeminiWire.functionResponses(results, ids: lastCallIDs))
        return try await post()
    }

    private func post() async throws -> ModelTurn {
        let address = "https://generativelanguage.googleapis.com/v1beta/models/\(config.model):generateContent"
        guard let url = URL(string: address) else { throw GeminiHTTPError(status: 0, body: "bad model name \(config.model)") }
        var request = URLRequest(url: url, timeoutInterval: config.requestTimeout)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = GeminiWire.requestBody(system: system, tools: tools, contents: contents, thinkingLevel: config.thinkingLevel)
        request.httpBody = try body.encodedData()

        await config.counter.increment()
        let (data, status) = try await HTTP.send(request)
        guard status == 200 else {
            throw GeminiHTTPError(status: status, body: String(bytes: data, encoding: .utf8) ?? "(\(data.count) bytes, not text)")
        }
        let parsed = try GeminiWire.parse(response: try JSON.parse(data))
        contents.append(parsed.modelContent)
        lastCallIDs = GeminiWire.callIDs(in: parsed.modelContent)
        return parsed.turn
    }
}

/// URLSession's callback API wrapped for async/await (the async API is missing on Linux). Cancelling the
/// task cancels the request, so the agent's timeout really stops a hung call.
enum HTTP {
    static func send(_ request: URLRequest) async throws -> (Data, Int) {
        let box = CancelBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, Int), Error>) in
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (data ?? Data(), (response as? HTTPURLResponse)?.statusCode ?? 0))
                    }
                }
                box.set(task)
                task.resume()
            }
        } onCancel: {
            box.cancel()
        }
    }
}

/// Holds the running request so a cancellation from another thread can stop it.
final class CancelBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false

    func set(_ task: URLSessionDataTask) {
        lock.lock()
        self.task = task
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { task.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let running = task
        lock.unlock()
        running?.cancel()
    }
}
