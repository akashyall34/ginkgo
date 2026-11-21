import CoreGraphics
import CoreImage
import Vision

/// A lifted subject as a grid of on/off pixels (like Photos' "lift subject"), top-left origin.
struct SubjectMask: Equatable {
    let width: Int
    let height: Int
    /// Row-major; true where the subject is.
    let pixels: [Bool]

    /// The four outermost corners of the subject, normalized 0...1 on the photo, in the app's
    /// order: top-left, top-right, bottom-right, bottom-left. Nil when the mask is empty.
    /// For a box-shaped face seen roughly head-on, these are the face's corners.
    var corners: [CGPoint]? {
        /// The pixel that scores best so far for one corner.
        struct Extreme {
            var score: Int
            var x: Int
            var y: Int
        }
        // Top-left has the smallest x + y, bottom-right the largest; top-right the largest x − y,
        // bottom-left the smallest.
        var extremes: [Extreme]?
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] {
                let sum = x + y, diff = x - y
                guard var e = extremes else {
                    extremes = [Extreme(score: sum, x: x, y: y), Extreme(score: diff, x: x, y: y),
                                Extreme(score: sum, x: x, y: y), Extreme(score: diff, x: x, y: y)]
                    continue
                }
                if sum < e[0].score { e[0] = Extreme(score: sum, x: x, y: y) }
                if diff > e[1].score { e[1] = Extreme(score: diff, x: x, y: y) }
                if sum > e[2].score { e[2] = Extreme(score: sum, x: x, y: y) }
                if diff < e[3].score { e[3] = Extreme(score: diff, x: x, y: y) }
                extremes = e
            }
        }
        // Pixel centers, so a one-pixel mask still has a position.
        return extremes?.map { CGPoint(x: (Double($0.x) + 0.5) / Double(width), y: (Double($0.y) + 0.5) / Double(height)) }
    }
}

/// Finds the subject under a tap, the way Photos lifts a subject out of the background.
protocol SubjectLifting {
    /// The mask of the subject at `point` (normalized, top-left origin), or nil if nothing is there.
    func lift(from image: CGImage, at point: CGPoint) -> SubjectMask?
}

/// Apple's on-device foreground segmentation (iOS 17+). Runs offline.
struct VisionSubjectLifter: SubjectLifting {
    func lift(from image: CGImage, at point: CGPoint) -> SubjectMask? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { return nil }

        // Which instance is under the tap.
        let labels = observation.instanceMask
        CVPixelBufferLockBaseAddress(labels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(labels, .readOnly) }
        let labelWidth = CVPixelBufferGetWidth(labels), labelHeight = CVPixelBufferGetHeight(labels)
        guard let base = CVPixelBufferGetBaseAddress(labels) else { return nil }
        let x = min(max(Int(point.x * Double(labelWidth)), 0), labelWidth - 1)
        let y = min(max(Int(point.y * Double(labelHeight)), 0), labelHeight - 1)
        let label = base.advanced(by: y * CVPixelBufferGetBytesPerRow(labels) + x).assumingMemoryBound(to: UInt8.self).pointee
        guard label != 0 else { return nil }

        // That instance at the label grid's resolution: plenty for four corners.
        var pixels = [Bool](repeating: false, count: labelWidth * labelHeight)
        let rowBytes = CVPixelBufferGetBytesPerRow(labels)
        for row in 0..<labelHeight {
            let line = base.advanced(by: row * rowBytes).assumingMemoryBound(to: UInt8.self)
            for column in 0..<labelWidth where line[column] == label { pixels[row * labelWidth + column] = true }
        }
        return SubjectMask(width: labelWidth, height: labelHeight, pixels: pixels)
    }
}
