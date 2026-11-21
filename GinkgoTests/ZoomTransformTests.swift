import XCTest
@testable import Ginkgo

final class ZoomTransformTests: XCTestCase {
    private let size = CGSize(width: 400, height: 600)

    func testNoZoomChangesNothing() {
        let z = ZoomTransform()
        let p = CGPoint(x: 123, y: 456)
        XCTAssertEqual(z.toContent(p, in: size), p)
        XCTAssertEqual(z.toView(p, in: size), p)
    }

    func testCenterStaysPutWhenZoomingWithoutPan() {
        let z = ZoomTransform(scale: 4)
        XCTAssertEqual(z.toContent(CGPoint(x: 200, y: 300), in: size), CGPoint(x: 200, y: 300))
    }

    func testZoomedTapLandsCloserToCenter() {
        // At 2×, a tap 100 pt right of center is 50 pt right of center on the content.
        let z = ZoomTransform(scale: 2)
        XCTAssertEqual(z.toContent(CGPoint(x: 300, y: 300), in: size), CGPoint(x: 250, y: 300))
    }

    func testPanShiftsWhatIsUnderTheFinger() {
        // Content dragged 100 pt right at 2×: the screen center shows content 50 pt left of center.
        let z = ZoomTransform(scale: 2, offset: CGSize(width: 100, height: 0))
        XCTAssertEqual(z.toContent(CGPoint(x: 200, y: 300), in: size), CGPoint(x: 150, y: 300))
    }

    func testToViewIsTheInverseOfToContent() {
        let z = ZoomTransform(scale: 3.7, offset: CGSize(width: -120, height: 85))
        for p in [CGPoint(x: 0, y: 0), CGPoint(x: 400, y: 600), CGPoint(x: 77, y: 512)] {
            let back = z.toView(z.toContent(p, in: size), in: size)
            XCTAssertEqual(back.x, p.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, p.y, accuracy: 1e-9)
        }
    }

    func testScaleIsClampedToRange() {
        XCTAssertEqual(ZoomTransform(scale: 0.3).clamped(in: size).scale, 1)
        XCTAssertEqual(ZoomTransform(scale: 50).clamped(in: size).scale, ZoomTransform.maxScale)
    }

    func testPanCannotRevealSpaceBeyondTheContent() {
        let z = ZoomTransform(scale: 2, offset: CGSize(width: 5000, height: -5000)).clamped(in: size)
        // At 2× the content overhangs by half the view size on each side.
        XCTAssertEqual(z.offset, CGSize(width: 200, height: -300))
        // The screen corner still shows the content's corner, not empty space.
        XCTAssertEqual(z.toContent(CGPoint(x: 0, y: 600), in: size), CGPoint(x: 0, y: 600))
    }

    func testNoPanAllowedAtNormalSize() {
        let z = ZoomTransform(scale: 1, offset: CGSize(width: 40, height: 40)).clamped(in: size)
        XCTAssertEqual(z.offset, .zero)
    }
}
