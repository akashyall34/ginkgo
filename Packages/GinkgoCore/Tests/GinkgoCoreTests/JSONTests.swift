import Foundation
@testable import GinkgoCore
import XCTest

final class JSONTests: XCTestCase {
    private func parse(_ text: String) throws -> JSON {
        try JSON.parse(Data(text.utf8))
    }

    func testNestedObjectRoundTrips() throws {
        let value: JSON = [
            "name": "seat",
            "size": [400, 300.5],
            "fits": true,
            "hint": nil,
            "spare": ["width": 52, "notes": []],
        ]
        XCTAssertEqual(try parse(value.encodedString()), value)
        XCTAssertEqual(try JSON.parse(value.encodedData()), value)
    }

    func testDecodesEveryKindOfValue() throws {
        let value = try parse(#"{"a": null, "b": false, "c": -2.5, "d": "x", "e": [1], "f": {"g": "h"}}"#)
        XCTAssertEqual(value["a"], .null)
        XCTAssertEqual(value["b"], .bool(false))
        XCTAssertEqual(value["c"], .number(-2.5))
        XCTAssertEqual(value["d"], .string("x"))
        XCTAssertEqual(value["e"], .array([.number(1)]))
        XCTAssertEqual(value["f"], .object(["g": .string("h")]))
    }

    func testBoolStaysBoolAndNumberStaysNumber() throws {
        XCTAssertEqual(try parse("true"), .bool(true))
        XCTAssertEqual(try parse("1"), .number(1))
        XCTAssertEqual(try parse("0"), .number(0))
        XCTAssertEqual(try parse(#"[true, 1, false, 0]"#), [true, 1, false, 0])
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try parse("{\"a\": "))
        XCTAssertThrowsError(try parse("{'a': 1}"))
        XCTAssertThrowsError(try parse(""))
    }

    func testEncodingSortsKeys() {
        let value: JSON = ["b": 1, "a": true, "c": ["z": "1", "y": "2"]]
        XCTAssertEqual(value.encodedString(), #"{"a":true,"b":1,"c":{"y":"2","z":"1"}}"#)
    }

    func testNonFiniteNumbersEncodeAsNull() {
        XCTAssertEqual(JSON.number(.nan).encodedString(), "null")
        XCTAssertEqual(JSON.array([.number(.infinity), 2]).encodedString(), "[null,2]")
    }

    func testAccessorsReturnNilForOtherKinds() {
        let value: JSON = ["s": "text", "n": 4.5, "b": true, "a": [1], "o": ["k": "v"]]
        XCTAssertEqual(value["s"]?.stringValue, "text")
        XCTAssertEqual(value["n"]?.numberValue, 4.5)
        XCTAssertEqual(value["b"]?.boolValue, true)
        XCTAssertEqual(value["a"]?.arrayValue, [1])
        XCTAssertEqual(value["o"]?.objectValue, ["k": "v"])
        XCTAssertEqual(value.objectValue?.count, 5)

        XCTAssertNil(value["missing"])
        XCTAssertNil(JSON.string("x")["key"])
        XCTAssertNil(JSON.number(1).stringValue)
        XCTAssertNil(JSON.string("1").numberValue)
        XCTAssertNil(JSON.number(1).boolValue)
        XCTAssertNil(JSON.null.arrayValue)
        XCTAssertNil(JSON.array([]).objectValue)
    }

    func testPlanRoundTripsThroughJSON() throws {
        let plan = try Fixtures.planBench()
        let json = try JSON.from(plan)
        XCTAssertEqual(json["id"], "plan-bench-1")
        XCTAssertEqual(json["new_parts"]?.arrayValue?.count, 3)
        XCTAssertEqual(json["new_parts"]?.arrayValue?.first?["span_mm"], 360)
        XCTAssertNil(json["overall_mm"], "an optional that is nil is left out, so the old example stays valid")
        XCTAssertEqual(try json.decode(Plan.self), plan)
    }

    func testDecodeWithTheWrongShapeThrows() {
        let notAPlan: JSON = ["id": "p1", "template": "bench"]
        XCTAssertThrowsError(try notAPlan.decode(Plan.self))
        let wrongTemplate: JSON = ["template": "castle", "new_parts": [], "steps": [], "hardware": []]
        XCTAssertThrowsError(try wrongTemplate.decode(PlanDraft.self))
    }

    func testInventoryFixtureLoads() throws {
        let inventory = try Fixtures.inventory()
        XCTAssertEqual(inventory.parts.map(\.id), ["top", "side_left", "side_right", "drawer_front"])
        XCTAssertEqual(inventory.parts.first?.keepOuts.count, 2)
    }

    func testNewSchemaShapesDecode() throws {
        let step: JSON = ["index": 0, "tool": "check_fit", "reason": "r", "summary": "s", "status": "pass"]
        XCTAssertEqual(try step.decode(AgentStep.self).tool, .checkFit)
        let limits = try JSON.object([:]).decode(SizeLimits.self)
        XCTAssertNil(limits.maxWidthMm, "every size limit is optional")
        let draft: JSON = [
            "template": "bench", "steps": [], "hardware": [],
            "new_parts": [["name": "seat", "source_part_id": "top", "width_mm": 400, "height_mm": 300, "role": "seat"]],
        ]
        XCTAssertEqual(try draft.decode(PlanDraft.self).newParts.first?.role, .seat)
    }
}
