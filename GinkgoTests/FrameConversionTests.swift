import CoreVideo
import simd
import UIKit
import XCTest
@testable import Ginkgo

final class FrameConversionTests: XCTestCase {
    /// A pixel buffer of the given format whose rows are padded, like real camera buffers.
    private func buffer(width: Int, height: Int, format: OSType, bytesPerValue: Int,
                        fill: (_ row: UnsafeMutableRawPointer, _ y: Int) -> Void) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferBytesPerRowAlignmentKey as String: 64] as CFDictionary
        XCTAssertEqual(CVPixelBufferCreate(nil, width, height, format, attrs, &pb), kCVReturnSuccess)
        let b = try XCTUnwrap(pb)
        CVPixelBufferLockBaseAddress(b, [])
        defer { CVPixelBufferUnlockBaseAddress(b, []) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(b))
        let rowBytes = CVPixelBufferGetBytesPerRow(b)
        XCTAssertGreaterThan(rowBytes, width * bytesPerValue, "Test needs padded rows to be meaningful")
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes)
            memset(row, 0xAB, rowBytes) // garbage in the padding
            fill(row, y)
        }
        return b
    }

    func testDepthIsCopiedRowByRowSkippingThePadding() throws {
        // 5 x 3 floats: value = 10 * row + column, in meters.
        let b = try buffer(width: 5, height: 3, format: kCVPixelFormatType_DepthFloat32, bytesPerValue: 4) { row, y in
            let f = row.assumingMemoryBound(to: Float.self)
            for x in 0..<5 { f[x] = Float(10 * y + x) }
        }
        let out = try XCTUnwrap(FrameConversion.depthValues(b))
        XCTAssertEqual(out.width, 5)
        XCTAssertEqual(out.height, 3)
        XCTAssertEqual(out.values, [0, 1, 2, 3, 4, 10, 11, 12, 13, 14, 20, 21, 22, 23, 24])
    }

    func testConfidenceIsCopiedRowByRowSkippingThePadding() throws {
        let b = try buffer(width: 4, height: 2, format: kCVPixelFormatType_OneComponent8, bytesPerValue: 1) { row, y in
            let p = row.assumingMemoryBound(to: UInt8.self)
            for x in 0..<4 { p[x] = UInt8((x + y) % 3) }
        }
        let out = try XCTUnwrap(FrameConversion.confidenceValues(b))
        XCTAssertEqual(out.values, [0, 1, 2, 0, 1, 2, 0, 1])
    }

    func testWrongFormatsAreRejected() throws {
        let bytes = try buffer(width: 4, height: 2, format: kCVPixelFormatType_OneComponent8, bytesPerValue: 1) { _, _ in }
        XCTAssertNil(FrameConversion.depthValues(bytes), "A byte buffer is not depth")
        let floats = try buffer(width: 4, height: 2, format: kCVPixelFormatType_DepthFloat32, bytesPerValue: 4) { _, _ in }
        XCTAssertNil(FrameConversion.confidenceValues(floats), "A float buffer is not confidence")
    }

    func testIntrinsicsReadTheColumnMajorMatrix() {
        // ARKit stores fx, fy on the diagonal and (cx, cy) in the third column.
        let k = simd_float3x3(columns: (SIMD3(1400, 0, 0), SIMD3(0, 1410, 0), SIMD3(955, 718, 1)))
        let i = FrameConversion.intrinsics(from: k, imageResolution: CGSize(width: 1920, height: 1440))
        XCTAssertEqual(i, Intrinsics(fx: 1400, fy: 1410, cx: 955, cy: 718, imageWidth: 1920, imageHeight: 1440))
    }

    func testOverlayIsRotatedUprightLikeThePhoto() throws {
        // A landscape 192 x 144 depth map becomes a portrait 144 x 192 overlay.
        let s = makeSnapshot(width: 192, height: 144) { _, _ in 1 }
        let overlay = try XCTUnwrap(UIImage.confidenceOverlay(for: s))
        XCTAssertEqual(overlay.size, CGSize(width: 144, height: 192))
    }

    func testCaptureErrorsExplainWhatToDo() {
        for error in [CaptureError.noFrameYet, .noDepth, .unreadableFrame] {
            XCTAssertTrue(error.explanation.contains("ry again"), "No next step in: \(error.explanation)")
        }
    }
}
