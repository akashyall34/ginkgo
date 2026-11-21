import SwiftUI

/// A draggable corner: 44 pt to touch, drawn smaller so it doesn't hide the corner.
struct CornerHandleView: View {
    let index: Int
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: TapTarget.minimum, height: TapTarget.minimum)
                .contentShape(Circle())
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Circle().fill(Palette.brand.opacity(isActive ? 0.8 : 0.5)))
                .frame(width: 22, height: 22)
                .shadow(radius: 2)
        }
        .accessibilityElement()
        .accessibilityLabel("Corner \(index + 1)")
        .accessibilityHint("Drag onto the face's corner.")
        .accessibilityIdentifier("corner\(index)")
    }
}

/// A magnified view of the photo under the finger, with crosshairs, floating above it.
struct LoupeView<Content: View>: View {
    let contentPoint: CGPoint
    let content: Content

    var body: some View {
        ZStack {
            content
                .scaleEffect(Loupe.magnification, anchor: .topLeading)
                .offset(Loupe.contentOffset(for: contentPoint))
                .frame(width: Loupe.size, height: Loupe.size, alignment: .topLeading)
            Rectangle().fill(Palette.brand).frame(width: 1, height: 24)
            Rectangle().fill(Palette.brand).frame(width: 24, height: 1)
        }
        .frame(width: Loupe.size, height: Loupe.size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
        .shadow(radius: 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
