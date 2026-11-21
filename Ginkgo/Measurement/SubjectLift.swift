import CoreGraphics

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
