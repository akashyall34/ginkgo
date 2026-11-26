import ARKit
import QuickLook
import RealityKit
import SwiftUI

/// The old furniture in 3D. "Transform" flies its panels apart and reassembles them into the new build;
/// "View in AR" places the build full size on the real floor.
struct TransformView: View {
    let scene: TransformScene

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TransformStage(scene: scene)
            } else {
                ContentUnavailableView("Needs iOS 18", systemImage: "cube",
                                       description: Text("Update iOS to see the build in 3D and AR."))
            }
        }
        .navigationTitle("Transform")
        .navigationBarTitleDisplayMode(.inline)
        .background(Palette.background)
    }
}

/// Holds the 3D panels so the buttons can move them.
@MainActor
private final class Stage {
    let root = Entity()
    var pieces: [(entity: ModelEntity, piece: TransformPiece)] = []
    var unused: [ModelEntity] = []

    static let wood = SimpleMaterial(color: Palette.wood, roughness: 0.75, isMetallic: false)
    static let spare = SimpleMaterial(color: Palette.unusedPanel, roughness: 0.9, isMetallic: false)

    static func panel(_ pose: PanelPose, material: SimpleMaterial) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(width: pose.size.x, height: pose.size.y, depth: pose.size.z, cornerRadius: 0.002),
                                 materials: [material])
        entity.transform = Transform(scale: .one, rotation: pose.rotation, translation: pose.position)
        return entity
    }

    func build(_ scene: TransformScene) {
        // Framed around the old furniture and the new build together, so neither leaves the view mid-animation.
        let framing = StageFraming.fit(scene.pieces.flatMap { [$0.start, $0.end] } + Array(scene.unused.values))
        root.scale = SIMD3(repeating: framing.scale)
        root.position = framing.offset
        for piece in scene.pieces {
            let entity = Self.panel(piece.start, material: Self.wood)
            root.addChild(entity)
            pieces.append((entity, piece))
        }
        for pose in scene.unused.values {
            let entity = Self.panel(pose, material: Self.spare)
            root.addChild(entity)
            unused.append(entity)
        }
    }

    func move(toEnd: Bool) {
        for (entity, piece) in pieces {
            let pose = toEnd ? piece.end : piece.start
            // Out and up first, so the pieces visibly come apart before they come together.
            let outward = pose.position * SIMD3(1.6, 1, 1.6) + SIMD3(0, 0.25, 0)
            let lifted = Transform(scale: .one, rotation: pose.rotation, translation: outward)
            entity.move(to: lifted, relativeTo: root, duration: 0.7, timingFunction: .easeOut)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                entity.move(to: Transform(scale: .one, rotation: pose.rotation, translation: pose.position),
                            relativeTo: self.root, duration: 0.9, timingFunction: .easeInOut)
            }
        }
        for entity in unused {
            var target = entity.transform
            target.scale = toEnd ? SIMD3(repeating: 0.001) : .one
            entity.move(to: target, relativeTo: root, duration: 0.6, timingFunction: .easeInOut)
        }
    }

    /// Writes the finished build as a Reality file, which AR Quick Look opens.
    @available(iOS 18.0, *)
    func exportBuild() async throws -> URL {
        let build = Entity()
        for (_, piece) in pieces { build.addChild(Self.panel(piece.end, material: Self.wood)) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ginkgo-build.reality")
        try? FileManager.default.removeItem(at: url)
        try await build.write(to: url)
        return url
    }
}

@available(iOS 18.0, *)
private struct TransformStage: View {
    let scene: TransformScene
    @State private var stage = Stage()
    @State private var assembled = false
    @State private var arFile: URL?
    @State private var exportFailed = false

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                stage.build(scene)
                content.add(stage.root)
                let light = DirectionalLight()
                light.light.intensity = 2500
                light.look(at: .zero, from: SIMD3(0.8, 1.5, 1.2), relativeTo: nil)
                // A directional light only needs its direction. Left out at 1.5 m, it would count in the bounds the
                // orbit camera fits to, and the build would be drawn tiny.
                light.position = .zero
                content.add(light)
            }
            .realityViewCameraControls(.orbit)
            .accessibilityLabel(assembled ? "The new build in 3D" : "The old furniture in 3D")
            .accessibilityIdentifier("transformStage")

            VStack(spacing: Spacing.small) {
                if exportFailed {
                    Text("The AR file couldn't be made. Try again.").font(.footnote).foregroundStyle(Palette.fails)
                }
                Button {
                    assembled.toggle()
                    stage.move(toEnd: assembled)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text(assembled ? "Show the original" : "Transform")
                        .font(.headline)
                        .foregroundStyle(Palette.onBrand)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand)
                .accessibilityIdentifier("transformButton")

                Button {
                    Task {
                        do { arFile = try await stage.exportBuild(); exportFailed = false } catch { exportFailed = true }
                    }
                } label: {
                    Label("View in AR", systemImage: "arkit")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.bordered)
                .tint(Palette.brand)
                .accessibilityIdentifier("arButton")
            }
            .padding(Spacing.medium)
            .background(Palette.background)
        }
        // Presented as a real modal, so Quick Look's own Done button works while the build is in the room.
        .background(ARQuickLook(file: $arFile))
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Apple's AR Quick Look, at true size (no pinch-to-scale), so the build is shown as big as it really is.
/// Quick Look must be presented modally: its Done button (the only way out of AR) lives in that presentation.
private struct ARQuickLook: UIViewControllerRepresentable {
    @Binding var file: URL?

    func makeCoordinator() -> Coordinator { Coordinator(file: $file) }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        guard let url = file, host.presentedViewController == nil else { return }
        let source = Source(url: url)
        context.coordinator.source = source
        let controller = QLPreviewController()
        controller.dataSource = source
        controller.delegate = context.coordinator
        host.present(controller, animated: true)
    }

    /// Clears the file when the person taps Done, so the screen is ready to show it again.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency QLPreviewControllerDelegate {
        @Binding var file: URL?
        var source: Source?

        init(file: Binding<URL?>) { _file = file }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            file = nil
            source = nil
        }
    }

    final class Source: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            let item = ARQuickLookPreviewItem(fileAt: url)
            item.allowsContentScaling = false
            return item
        }
    }
}
