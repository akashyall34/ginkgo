import CoreGraphics
import Vision

/// A rectangular face found in the portrait photo. Corners are normalized 0...1
/// with the origin at the top-left, in order: top-left, top-right, bottom-right,
/// bottom-left.
struct DetectedQuad: Equatable {
    let corners: [CGPoint]

    func contains(_ p: CGPoint) -> Bool {
        Polygon.contains(corners.map { SIMD2(Float($0.x), Float($0.y)) }, SIMD2(Float(p.x), Float(p.y)))
    }

    /// The corners in the raw landscape image, ready for measuring.
    var rawCorners: [ImagePoint] {
        corners.map { Geometry.rawImagePoint(fromPortrait: Float($0.x), Float($0.y)) }
    }
}

enum RectangleDetector {
    /// Vision's normalized points have their origin at the bottom-left; flip to top-left.
    static func fromVision(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }

    /// Runs Vision. Tests swap it to simulate a failure or no results.
    typealias Perform = (VNImageRequestHandler, [VNRequest]) throws -> Void

    /// Finds rectangular faces, largest first. If Vision fails, nothing is found (the user can still
    /// place the corners by hand).
    static func detect(in image: CGImage, perform: Perform = { try $0.perform($1) }) -> [DetectedQuad] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 8
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.1
        request.minimumSize = 0.05
        // Faces seen at an angle look like trapezoids, not rectangles.
        request.quadratureTolerance = 40

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try perform(handler, [request])
        } catch {
            return []
        }
        let quads = (request.results ?? []).map { o in
            DetectedQuad(corners: [o.topLeft, o.topRight, o.bottomRight, o.bottomLeft].map(fromVision))
        }
        return quads.sorted { area($0) > area($1) }
    }

    static func area(_ q: DetectedQuad) -> CGFloat {
        let c = q.corners
        var sum: CGFloat = 0
        for i in 0..<c.count {
            let a = c[i], b = c[(i + 1) % c.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }
}
