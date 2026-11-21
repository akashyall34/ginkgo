import SwiftUI

/// The captured photo with its depth-quality overlay, outlined faces, corner handles,
/// a loupe while dragging, and pinch-to-zoom. Every action goes to the model.
struct FrozenPhotoView: View {
    let model: ScanModel
    let frame: CapturedFrame
    let showDepthQuality: Bool

    @State private var zoom = ZoomTransform()
    @State private var pinchStart: ZoomTransform?
    @State private var panStart: ZoomTransform?
    @State private var dragging: Int?
    @State private var dragLocation: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                photoLayers
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(zoom.scale)
                    .offset(zoom.offset)
                    .allowsHitTesting(false)
                outlines(in: geo.size)
                if let corners = model.corners {
                    ForEach(0..<corners.count, id: \.self) { i in
                        handle(i, at: corners[i], in: geo.size)
                    }
                }
                if let dragLocation, dragging != nil {
                    LoupeView(contentPoint: zoom.toContent(dragLocation, in: geo.size),
                              content: photoLayers.frame(width: geo.size.width, height: geo.size.height))
                        .position(Loupe.center(forFinger: dragLocation, in: geo.size))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "photo")
            .clipped()
            .contentShape(Rectangle())
            .gesture(zoomAndPan(in: geo.size))
            .onTapGesture { location in
                if let p = normalized(location, in: geo.size, clamped: false) { model.selectFace(at: p) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Captured photo")
            .accessibilityIdentifier("photo")
        }
    }

    private var photoLayers: some View {
        ZStack {
            Image(uiImage: frame.image).resizable().scaledToFit()
            if showDepthQuality {
                Image(uiImage: frame.confidenceOverlay)
                    .resizable().interpolation(.none).scaledToFit()
            }
        }
    }

    /// Where a normalized photo point appears on screen, at the current zoom.
    private func screen(_ p: CGPoint, in size: CGSize) -> CGPoint {
        zoom.toView(ScreenMapping.viewPoint(normalized: p, imageSize: frame.image.size, viewSize: size), in: size)
    }

    private func normalized(_ location: CGPoint, in size: CGSize, clamped: Bool) -> CGPoint? {
        let onContent = zoom.toContent(location, in: size)
        return clamped
            ? ScreenMapping.clampedNormalizedPoint(onContent, imageSize: frame.image.size, viewSize: size)
            : ScreenMapping.normalizedPoint(tap: onContent, imageSize: frame.image.size, viewSize: size)
    }

    @ViewBuilder private func outlines(in size: CGSize) -> some View {
        if let corners = model.corners {
            outline(corners.map { screen($0, in: size) }, color: Palette.verified, width: 3)
        } else {
            ForEach(Array(model.faces.enumerated()), id: \.offset) { _, face in
                outline(face.corners.map { screen($0, in: size) }, color: Palette.brand, width: 2)
            }
        }
    }

    private func outline(_ points: [CGPoint], color: Color, width: CGFloat) -> some View {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
        .stroke(color, lineWidth: width)
        .allowsHitTesting(false)
    }

    private func handle(_ i: Int, at point: CGPoint, in size: CGSize) -> some View {
        CornerHandleView(index: i, isActive: dragging == i)
            .position(screen(point, in: size))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("photo"))
                    .onChanged { value in
                        dragging = i
                        dragLocation = value.location
                        if let p = normalized(value.location, in: size, clamped: true) { model.moveCorner(i, to: p) }
                    }
                    .onEnded { _ in
                        dragging = nil
                        dragLocation = nil
                        model.finishMovingCorner()
                    }
            )
    }

    private func zoomAndPan(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchStart ?? zoom
                pinchStart = base
                zoom = ZoomTransform(scale: base.scale * value.magnification, offset: base.offset).clamped(in: size)
            }
            .onEnded { _ in pinchStart = nil }
            .simultaneously(with: DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let base = panStart ?? zoom
                    panStart = base
                    zoom = ZoomTransform(scale: zoom.scale,
                                         offset: CGSize(width: base.offset.width + value.translation.width,
                                                        height: base.offset.height + value.translation.height))
                        .clamped(in: size)
                }
                .onEnded { _ in panStart = nil })
    }
}
