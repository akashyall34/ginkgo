import CoreImage
import UIKit

/// One frozen frame: the photo shown to the user and the LiDAR depth behind it.
struct CapturedFrame {
    /// The camera image rotated upright for portrait display.
    let image: UIImage
    /// Where depth is reliable, drawn over the photo: clear = high, yellow = medium, red = low.
    let confidenceOverlay: UIImage
    let snapshot: DepthSnapshot
}

extension UIImage {
    /// The confidence map drawn as a tint, rotated upright like the photo.
    static func confidenceOverlay(for s: DepthSnapshot, context: CIContext = CIContext()) -> UIImage? {
        let data = Data(ConfidenceTint.pixels(s.confidence)) as CFData
        guard let provider = CGDataProvider(data: data),
              let raw = CGImage(width: s.width, height: s.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: s.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: false,
                                intent: .defaultIntent) else { return nil }
        let upright = CIImage(cgImage: raw).oriented(.right)
        guard let cg = context.createCGImage(upright, from: upright.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
