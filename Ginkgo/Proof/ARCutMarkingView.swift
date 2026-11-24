import ARKit
import GinkgoCore
import RealityKit
import SwiftUI

/// The cut lines drawn on the real panel: tap its bottom-left, bottom-right and top-left corners on the floor,
/// and every line appears where the pencil goes. Needs an AR-capable iPhone; checked on a real device.
struct ARCutMarkingView: View {
    @State private var model: CutMarkingModel

    init(panel: PanelGuide) {
        _model = State(initialValue: CutMarkingModel(panel: panel))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ARCutLinesContainer(model: $model).ignoresSafeArea()
            VStack(spacing: Spacing.small) {
                Text(model.prompt).font(.headline).multilineTextAlignment(.center)
                    .accessibilityIdentifier("arPrompt")
                if let problem = model.problem {
                    Text(problem).font(.callout).foregroundStyle(Palette.fails).multilineTextAlignment(.center)
                        .accessibilityIdentifier("arProblem")
                }
                if !model.taps.isEmpty || model.frame != nil {
                    Button("Start over") { model.reset() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: TapTarget.minimum)
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .navigationTitle("Mark with AR")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// ARKit glue: finds the floor, turns a tap into a point on it, and draws the model's lines as thin green bars.
private struct ARCutLinesContainer: UIViewRepresentable {
    @Binding var model: CutMarkingModel
    /// Drawn lines: 1.5 mm wide, 0.5 mm above the panel so they sit on its surface.
    static let lineWidth: Float = 0.0015
    static let lift: Float = 0.0005

    func makeCoordinator() -> Coordinator { Coordinator(model: $model) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        view.session.run(configuration)
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(Coordinator.tapped(_:))))
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.draw(model)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        view.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject {
        var model: Binding<CutMarkingModel>
        weak var view: ARView?
        private var anchor: AnchorEntity?

        init(model: Binding<CutMarkingModel>) { self.model = model }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            let location = gesture.location(in: view)
            guard let hit = view.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first else { return }
            let column = hit.worldTransform.columns.3
            model.wrappedValue.tap(SIMD3(column.x, column.y, column.z))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        func draw(_ model: CutMarkingModel) {
            guard let view else { return }
            anchor?.removeFromParent()
            anchor = nil
            let lines = model.lines
            guard !lines.isEmpty, let frame = model.frame else { return }
            let up = simd_normalize(simd_cross(frame.xAxis, frame.yAxis))
            let root = AnchorEntity(world: .zero)
            let material = SimpleMaterial(color: .systemGreen, isMetallic: false)
            for (start, end) in lines {
                let length = simd_distance(start, end)
                guard length > 0 else { continue }
                let bar = ModelEntity(mesh: .generateBox(size: SIMD3(length, ARCutLinesContainer.lineWidth / 2,
                                                                      ARCutLinesContainer.lineWidth)),
                                      materials: [material])
                bar.position = (start + end) / 2 + up * ARCutLinesContainer.lift
                bar.orientation = simd_quatf(from: SIMD3(1, 0, 0), to: simd_normalize(end - start))
                root.addChild(bar)
            }
            view.scene.addAnchor(root)
            anchor = root
        }
    }
}
