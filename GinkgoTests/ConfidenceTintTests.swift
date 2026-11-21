import XCTest
@testable import Ginkgo

final class ConfidenceTintTests: XCTestCase {
    func testHighConfidenceIsClear() {
        XCTAssertEqual(ConfidenceTint.rgba(for: 2).a, 0)
    }

    func testMediumIsYellowAndLowIsRed() {
        let medium = ConfidenceTint.rgba(for: 1)
        XCTAssertGreaterThan(medium.r, 0); XCTAssertGreaterThan(medium.g, 0); XCTAssertEqual(medium.b, 0)
        let low = ConfidenceTint.rgba(for: 0)
        XCTAssertGreaterThan(low.r, 0); XCTAssertEqual(low.g, 0); XCTAssertEqual(low.b, 0)
        XCTAssertGreaterThan(low.a, medium.a, "Low confidence should stand out more than medium")
    }

    func testColorsArePremultiplied() {
        // Premultiplied RGBA: no channel may exceed alpha, or the overlay draws wrong.
        for c: UInt8 in [0, 1, 2] {
            let p = ConfidenceTint.rgba(for: c)
            XCTAssertLessThanOrEqual(p.r, p.a); XCTAssertLessThanOrEqual(p.g, p.a); XCTAssertLessThanOrEqual(p.b, p.a)
        }
    }

    func testPixelsKeepOrderAndSize() {
        let px = ConfidenceTint.pixels([2, 0, 1])
        XCTAssertEqual(px.count, 12)
        XCTAssertEqual(px[3], 0)                         // first pixel clear
        XCTAssertEqual(px[7], ConfidenceTint.rgba(for: 0).a)  // second pixel red
        XCTAssertEqual(px[11], ConfidenceTint.rgba(for: 1).a) // third pixel yellow
    }
}

final class MeasureErrorMessageTests: XCTestCase {
    private let every: [PlaneMeasureError] = [
        .samePoint, .outsideImage, .notEnoughSurface(usable: 12, needed: 30), .noFlatSurface,
        .missesSurface(point: 2), .tooShallow(degrees: 78), .tooUncertain(meters: 0.017),
    ]

    func testEveryErrorHasAMessage() {
        for error in every {
            XCTAssertFalse(error.explanation.isEmpty, "\(error) has no message")
        }
    }

    func testMessagesGiveTheNumbersThatMatter() {
        XCTAssertTrue(PlaneMeasureError.notEnoughSurface(usable: 12, needed: 30).explanation.contains("12"))
        XCTAssertTrue(PlaneMeasureError.notEnoughSurface(usable: 12, needed: 30).explanation.contains("30"))
        XCTAssertTrue(PlaneMeasureError.missesSurface(point: 2).explanation.contains("Point 2"))
        XCTAssertTrue(PlaneMeasureError.tooShallow(degrees: 78).explanation.contains("78°"))
        XCTAssertTrue(PlaneMeasureError.tooUncertain(meters: 0.017).explanation.contains("1.7 cm"))
    }

    func testMessagesThatCanBeFixedSayHow() {
        // Every message except a plain fact tells the person what to do next.
        let actionable: [PlaneMeasureError] = [.notEnoughSurface(usable: 1, needed: 30), .noFlatSurface,
                                                .missesSurface(point: 1), .tooShallow(degrees: 80),
                                                .tooUncertain(meters: 0.02), .samePoint]
        let verbs = ["Move", "Measure", "Capture", "Tap"]
        for error in actionable {
            XCTAssertTrue(verbs.contains { error.explanation.contains($0) }, "No next step in: \(error.explanation)")
        }
    }
}
