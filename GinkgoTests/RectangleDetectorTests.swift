import XCTest
import CoreGraphics
@testable import Ginkgo

final class RectangleDetectorTests: XCTestCase {
    /// Draws a light rectangle on a dark background, like a white box on a carpet.
    /// `rect` is in normalized top-left coordinates.
    private func image(with rect: CGRect, size: CGSize = CGSize(width: 720, height: 960)) throws -> CGImage {
        let ctx = try XCTUnwrap(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1))
        // CGContext's origin is bottom-left.
        ctx.fill(CGRect(x: rect.minX * size.width, y: (1 - rect.maxY) * size.height,
                        width: rect.width * size.width, height: rect.height * size.height))
        return try XCTUnwrap(ctx.makeImage())
    }

    func testVisionCoordinatesAreFlippedToTopLeft() {
        let p = RectangleDetector.fromVision(CGPoint(x: 0.2, y: 0.9))
        XCTAssertEqual(p.x, 0.2, accuracy: 1e-12)
        XCTAssertEqual(p.y, 0.1, accuracy: 1e-12)
    }

    func testFindsARectangleWithCornersInOrder() throws {
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.5, height: 0.3)
        let quad = try XCTUnwrap(RectangleDetector.detect(in: try image(with: rect)).first)
        let expected = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                        CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        for (found, want) in zip(quad.corners, expected) {
            XCTAssertEqual(found.x, want.x, accuracy: 0.01, "Corner x off: \(found) vs \(want)")
            XCTAssertEqual(found.y, want.y, accuracy: 0.01, "Corner y off: \(found) vs \(want)")
        }
    }

    func testTapInsideSelectsTheQuad() throws {
        let quad = try XCTUnwrap(RectangleDetector.detect(in: try image(with: CGRect(x: 0.2, y: 0.3, width: 0.5, height: 0.3))).first)
        XCTAssertTrue(quad.contains(CGPoint(x: 0.45, y: 0.45)))
        XCTAssertFalse(quad.contains(CGPoint(x: 0.1, y: 0.1)))
    }

    func testBlankImageFindsNothing() throws {
        XCTAssertTrue(RectangleDetector.detect(in: try image(with: .zero)).isEmpty)
    }

    func testAreaOfAKnownQuad() {
        let q = DetectedQuad(corners: [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 0.2), CGPoint(x: 0, y: 0.2)])
        XCTAssertEqual(RectangleDetector.area(q), 0.1, accuracy: 1e-9)
    }

    func testRawCornersUseThePortraitMapping() {
        let q = DetectedQuad(corners: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)])
        XCTAssertEqual(q.rawCorners, [ImagePoint(u: 0, v: 1), ImagePoint(u: 0, v: 0),
                                      ImagePoint(u: 1, v: 0), ImagePoint(u: 1, v: 1)])
    }
}
