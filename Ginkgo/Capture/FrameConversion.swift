import CoreGraphics
import CoreVideo
import simd

/// A rectangle of values read from a camera buffer, row by row.
struct Grid<Value> {
    let width: Int
    let height: Int
    let values: [Value]
}

/// Pure conversions from ARKit's camera data, kept apart from the AR session so they
/// can be tested without a camera.
enum FrameConversion {
    /// ARKit's intrinsics matrix is column-major: fx and fy on the diagonal, the
    /// principal point (cx, cy) in the third column.
    static func intrinsics(from k: simd_float3x3, imageResolution: CGSize) -> Intrinsics {
        Intrinsics(fx: k[0][0], fy: k[1][1], cx: k[2][0], cy: k[2][1],
                   imageWidth: Float(imageResolution.width), imageHeight: Float(imageResolution.height))
    }

    /// The depth map's values in meters, or nil if the buffer isn't 32-bit float depth.
    static func depthValues(_ buffer: CVPixelBuffer) -> Grid<Float>? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_DepthFloat32 else { return nil }
        return copy(buffer, as: Float.self)
    }

    /// The confidence map's values (0 low, 1 medium, 2 high), or nil if the buffer
    /// isn't one byte per pixel.
    static func confidenceValues(_ buffer: CVPixelBuffer) -> Grid<UInt8>? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8 else { return nil }
        return copy(buffer, as: UInt8.self)
    }

    /// Copies a single-plane pixel buffer row by row. Rows can be padded past the
    /// image width, so each row starts at its own offset.
    private static func copy<T>(_ buffer: CVPixelBuffer, as: T.Type) -> Grid<T>? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var values: [T] = []
        values.reserveCapacity(width * height)
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: T.self)
            values.append(contentsOf: UnsafeBufferPointer(start: row, count: width))
        }
        return Grid(width: width, height: height, values: values)
    }
}
