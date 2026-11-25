import XCTest
@testable import GinkgoCore

final class ValidatorSettingsTests: XCTestCase {
    override func tearDown() {
        ValidatorSettings.current = ValidatorSettings()
        super.tearDown()
    }

    func testWithNothingRemoteTheBuiltInLimitsApply() {
        XCTAssertEqual(Packer.margin, 8)
        XCTAssertEqual(Sag.limit(spanMm: 600), 1)
        XCTAssertEqual(Sag.designLoadKg(for: .seat), 100)
        XCTAssertEqual(Sag.designLoadKg(for: .shelf), 30)
    }

    func testAStricterRemoteValueIsUsed() {
        ValidatorSettings.current = ValidatorSettings(remote: [.marginMm: 10, .sagSpanDivisor: 900,
                                                               .seatLoadKg: 120, .shelfLoadKg: 40])
        XCTAssertEqual(Packer.margin, 10)
        XCTAssertEqual(Sag.limit(spanMm: 900), 1)
        XCTAssertEqual(Sag.designLoadKg(for: .seat), 120)
        XCTAssertEqual(Sag.designLoadKg(for: .shelf), 40)
    }

    func testALooserRemoteValueIsIgnored() {
        ValidatorSettings.current = ValidatorSettings(remote: [.marginMm: 2, .sagSpanDivisor: 200, .seatLoadKg: 50])
        XCTAssertEqual(Packer.margin, 8, "A smaller margin would let cuts overlap the kerf")
        XCTAssertEqual(Sag.limit(spanMm: 600), 1, "A smaller divisor would allow more sag")
        XCTAssertEqual(Sag.designLoadKg(for: .seat), 100)
    }

    func testATypoBeyondTheGuardIsIgnored() {
        ValidatorSettings.current = ValidatorSettings(remote: [.marginMm: 80, .seatLoadKg: 1000])
        XCTAssertEqual(Packer.margin, 8, "80 mm is 10× the built-in margin: taken as a typo")
        XCTAssertEqual(Sag.designLoadKg(for: .seat), 100)
        XCTAssertEqual(ValidatorSettings.current.value(.marginMm, builtIn: 8), 8)
        XCTAssertEqual(ValidatorSettings(remote: [.marginMm: 32]).value(.marginMm, builtIn: 8), 32, "4× is allowed")
    }

    func testNotANumberIsIgnored() {
        XCTAssertEqual(ValidatorSettings(remote: [.marginMm: .nan]).value(.marginMm, builtIn: 8), 8)
        XCTAssertEqual(ValidatorSettings(remote: [.marginMm: .infinity]).value(.marginMm, builtIn: 8), 8)
    }

    func testIgnoredKeysAreReported() {
        let settings = ValidatorSettings(remote: [.marginMm: 2, .seatLoadKg: 120])
        XCTAssertEqual(settings.ignored(builtIns: [.marginMm: 8, .seatLoadKg: 100]), [.marginMm])
    }

    func testAStricterMarginTurnsAnExactFitIntoAMiss() {
        let panel = Part(damaged: false, heightMm: 400, id: "panel", keepOuts: [], material: .plywood, thicknessMm: 18,
                         type: .top, widthMm: 460)
        let seat = CutRequest(name: "seat", widthMm: 452, heightMm: 392)
        XCTAssertEqual(Packer.pack(source: panel, cuts: [seat]).failures, [], "Fits with the built-in 8 mm margin")
        ValidatorSettings.current = ValidatorSettings(remote: [.marginMm: 10])
        XCTAssertEqual(Packer.pack(source: panel, cuts: [seat]).failures.count, 1, "A 10 mm margin leaves no room")
    }
}
