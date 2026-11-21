import XCTest
@testable import Ginkgo

final class ScreenMappingTests: XCTestCase {
    // A portrait 3:4 camera image (1440×1920) on a tall phone screen.
    private let image = CGSize(width: 1440, height: 1920)
    private let screen = CGSize(width: 390, height: 700)

    func testFitsToWidthAndCentersVertically() {
        let r = ScreenMapping.fittedRect(imageSize: image, in: screen)
        XCTAssertEqual(r.width, 390, accuracy: 1e-9)
        XCTAssertEqual(r.height, 520, accuracy: 1e-9)
        XCTAssertEqual(r.minX, 0, accuracy: 1e-9)
        XCTAssertEqual(r.minY, 90, accuracy: 1e-9)
    }

    func testFitsToHeightAndCentersHorizontallyInAWideView() {
        let r = ScreenMapping.fittedRect(imageSize: image, in: CGSize(width: 800, height: 400))
        XCTAssertEqual(r.height, 400, accuracy: 1e-9)
        XCTAssertEqual(r.width, 300, accuracy: 1e-9)
        XCTAssertEqual(r.minX, 250, accuracy: 1e-9)
    }

    func testTapCornersMapToImageCorners() throws {
        let tl = try XCTUnwrap(ScreenMapping.normalizedPoint(tap: CGPoint(x: 0, y: 90), imageSize: image, viewSize: screen))
        XCTAssertEqual(tl.x, 0, accuracy: 1e-9); XCTAssertEqual(tl.y, 0, accuracy: 1e-9)
        let br = try XCTUnwrap(ScreenMapping.normalizedPoint(tap: CGPoint(x: 390, y: 610), imageSize: image, viewSize: screen))
        XCTAssertEqual(br.x, 1, accuracy: 1e-9); XCTAssertEqual(br.y, 1, accuracy: 1e-9)
    }

    func testTapCenterMapsToImageCenter() throws {
        let c = try XCTUnwrap(ScreenMapping.normalizedPoint(tap: CGPoint(x: 195, y: 350), imageSize: image, viewSize: screen))
        XCTAssertEqual(c.x, 0.5, accuracy: 1e-9); XCTAssertEqual(c.y, 0.5, accuracy: 1e-9)
    }

    func testTapsOnTheLetterboxBarsAreIgnored() {
        XCTAssertNil(ScreenMapping.normalizedPoint(tap: CGPoint(x: 195, y: 50), imageSize: image, viewSize: screen))
        XCTAssertNil(ScreenMapping.normalizedPoint(tap: CGPoint(x: 195, y: 650), imageSize: image, viewSize: screen))
        XCTAssertNil(ScreenMapping.normalizedPoint(tap: CGPoint(x: -1, y: 350), imageSize: image, viewSize: screen))
    }

    func testViewPointIsTheInverseOfNormalizedPoint() throws {
        for tap in [CGPoint(x: 10, y: 100), CGPoint(x: 200, y: 400), CGPoint(x: 389, y: 609)] {
            let n = try XCTUnwrap(ScreenMapping.normalizedPoint(tap: tap, imageSize: image, viewSize: screen))
            let back = ScreenMapping.viewPoint(normalized: n, imageSize: image, viewSize: screen)
            XCTAssertEqual(back.x, tap.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, tap.y, accuracy: 1e-9)
        }
    }

    func testEmptySizesGiveNoRectAndNoTap() {
        XCTAssertEqual(ScreenMapping.fittedRect(imageSize: .zero, in: screen), .zero)
        XCTAssertNil(ScreenMapping.normalizedPoint(tap: CGPoint(x: 1, y: 1), imageSize: image, viewSize: .zero))
    }
}
