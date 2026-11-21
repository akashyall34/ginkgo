@testable import GinkgoCore
import XCTest

final class GeminiWireTests: XCTestCase {
    private let signature = "EpcBCpQBAWkUfRNJ+/z=="

    private func response(_ parts: [JSON]) -> JSON {
        ["candidates": [["content": ["role": "model", "parts": .array(parts)], "finishReason": "STOP", "index": 0]]]
    }

    private func callPart(_ name: String, id: String? = nil, args: JSON? = nil, signature: String? = nil) -> JSON {
        var call: [String: JSON] = ["name": .string(name)]
        if let args { call["args"] = args }
        if let id { call["id"] = .string(id) }
        var part: [String: JSON] = ["functionCall": .object(call)]
        if let signature { part["thoughtSignature"] = .string(signature) }
        return .object(part)
    }

    // MARK: - parse

    func testSingleCallKeepsTheSignatureExactly() throws {
        let part = callPart("check_width", id: "call_1", args: ["needed_mm": 408, "available_mm": 460], signature: signature)
        let raw = response([part])
        let parsed = try GeminiWire.parse(response: raw)
        XCTAssertEqual(parsed.modelContent, raw["candidates"]?.arrayValue?.first?["content"], "appended verbatim, never rebuilt")
        XCTAssertEqual(parsed.modelContent["parts"]?.arrayValue?.first?["thoughtSignature"], .string(signature))
        XCTAssertTrue(parsed.modelContent.encodedString().contains(signature))
        XCTAssertEqual(parsed.turn.calls, [ToolCall(name: "check_width", args: ["needed_mm": 408, "available_mm": 460])])
        XCTAssertNil(parsed.turn.text)
        XCTAssertEqual(GeminiWire.callIDs(in: parsed.modelContent), ["call_1"])
    }

    func testParallelCallsInOrderWithOnlyTheFirstSigned() throws {
        let raw = response([callPart("check_fit", id: "a", args: ["x": 1], signature: signature), callPart("check_sag", args: ["y": 2])])
        let parsed = try GeminiWire.parse(response: raw)
        XCTAssertEqual(parsed.turn.calls.map(\.name), ["check_fit", "check_sag"])
        XCTAssertEqual(parsed.turn.calls.last?.args, ["y": 2])
        XCTAssertEqual(GeminiWire.callIDs(in: parsed.modelContent), ["a", nil])
    }

    func testCallWithoutArgsGetsAnEmptyObject() throws {
        let parsed = try GeminiWire.parse(response: response([callPart("check_fit")]))
        XCTAssertEqual(parsed.turn.calls.first?.args, [:])
    }

    func testTextOnlyAndThoughtsAreSkipped() throws {
        let raw = response([["text": "Planning the cuts...", "thought": true], ["text": "I'd make "], ["text": "a bench."]])
        let parsed = try GeminiWire.parse(response: raw)
        XCTAssertEqual(parsed.turn.calls, [])
        XCTAssertEqual(parsed.turn.text, "I'd make a bench.")
        XCTAssertNil(try GeminiWire.parse(response: response([["text": "secret", "thought": true]])).turn.text)
    }

    func testBlockedResponsesThrow() {
        XCTAssertThrowsError(try GeminiWire.parse(response: ["candidates": [["finishReason": "SAFETY"]]])) { error in
            XCTAssertEqual(error as? GeminiWireError, .blocked("SAFETY"))
            XCTAssertEqual("\(error)", "Gemini returned no answer (SAFETY)")
        }
        XCTAssertThrowsError(try GeminiWire.parse(response: ["promptFeedback": ["blockReason": "OTHER"]])) { error in
            XCTAssertEqual(error as? GeminiWireError, .blocked("OTHER"))
        }
        XCTAssertThrowsError(try GeminiWire.parse(response: [:])) { error in
            XCTAssertEqual(error as? GeminiWireError, .blocked("no candidates"))
        }
        XCTAssertThrowsError(try GeminiWire.parse(response: ["candidates": [["content": ["role": "model"]]]])) { error in
            XCTAssertEqual(error as? GeminiWireError, .blocked("no content"))
        }
    }

    // MARK: - Requests

    func testRequestBodyShape() throws {
        let body = GeminiWire.requestBody(system: "Be careful.", tools: AgentTools.all, contents: [GeminiWire.userText("Hi")],
                                          thinkingLevel: "low")
        XCTAssertEqual(body["systemInstruction"], ["parts": [["text": "Be careful."]]])
        XCTAssertEqual(body["contents"], [["role": "user", "parts": [["text": "Hi"]]]])
        XCTAssertEqual(body["generationConfig"], ["thinkingConfig": ["thinkingLevel": "low"]])
        let declarations = try XCTUnwrap(body["tools"]?.arrayValue?.first?["functionDeclarations"]?.arrayValue)
        XCTAssertEqual(declarations.map { $0["name"] }, ["check_fit", "check_sag", "submit_plan"])

        let fit = try XCTUnwrap(declarations.first?["parameters"])
        XCTAssertEqual(fit["type"], "OBJECT")
        XCTAssertEqual(fit["required"], ["reason", "placements"])
        let item = try XCTUnwrap(fit["properties"]?["placements"]?["items"])
        XCTAssertEqual(fit["properties"]?["placements"]?["type"], "ARRAY")
        XCTAssertEqual(item["properties"]?["width_mm"]?["type"], "NUMBER")
        XCTAssertEqual(item["properties"]?["new_part"]?["type"], "STRING")

        let plan = try XCTUnwrap(declarations.last?["parameters"]?["properties"]?["plan"])
        XCTAssertEqual(plan["properties"]?["template"]?["enum"], ["bench", "bookshelf", "no_cut"])
        let part = try XCTUnwrap(plan["properties"]?["new_parts"]?["items"])
        XCTAssertEqual(part["required"]?.arrayValue?.contains("span_mm"), false, "span_mm is optional")
        XCTAssertEqual(plan["properties"]?["hardware"]?["items"]?["properties"]?["quantity"]?["type"], "INTEGER")
    }

    func testRequestEncodingIsStableAndThinkingIsOptional() {
        let first = GeminiWire.requestBody(system: "S", tools: AgentTools.all, contents: [], thinkingLevel: "low").encodedString()
        let second = GeminiWire.requestBody(system: "S", tools: AgentTools.all, contents: [], thinkingLevel: "low").encodedString()
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasPrefix(#"{"contents":[],"generationConfig":"#), "keys are sorted")
        XCTAssertNil(GeminiWire.requestBody(system: "S", tools: [], contents: [], thinkingLevel: nil)["generationConfig"])
    }

    func testSchemaForEveryKind() {
        XCTAssertEqual(GeminiWire.schema(.boolean("ok?")), ["type": "BOOLEAN", "description": "ok?"])
        XCTAssertEqual(GeminiWire.schema(.integer("n")), ["type": "INTEGER", "description": "n"])
        XCTAssertEqual(GeminiWire.schema(.object([], "empty")), ["type": "OBJECT", "description": "empty", "properties": [:]],
                       "no required list when nothing is required")
    }

    func testFunctionResponsesGoInOneMessageInCallOrder() {
        let results = [
            ToolResult(name: "check_fit", response: ["all_fit": true]), ToolResult(name: "check_sag", response: ["all_pass": false]),
        ]
        XCTAssertEqual(GeminiWire.functionResponses(results, ids: ["a", nil]), ["role": "user", "parts": [
            ["functionResponse": ["name": "check_fit", "response": ["all_fit": true], "id": "a"]],
            ["functionResponse": ["name": "check_sag", "response": ["all_pass": false]]],
        ]])
        XCTAssertEqual(GeminiWire.functionResponses(results)["parts"]?.arrayValue?.count, 2, "ids are optional")
        XCTAssertEqual(GeminiWire.callIDs(in: ["role": "model"]), [])
    }
}
