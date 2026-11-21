import CoreGraphics
import CoreVideo
import Vision

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
