import GinkgoCore
import RealityKit
import SwiftUI

/// Put it together, one step at a time: the step in words, and in 3D only the pieces in place so far, the newest
/// one highlighted. Steps, screws and brackets come from tested rules, never from the AI.
struct AssemblyView: View {
    @State private var model: AssemblyModel

    init(plan: Plan, inventory: Inventory) {
        _model = State(initialValue: AssemblyModel(plan: plan, inventory: inventory))
    }

    var body: some View {
        VStack(spacing: 0) {
            if #available(iOS 18.0, *) {
                AssemblyStage(model: model).frame(minHeight: 260)
            }
            List {
                Section {
                    Text(model.title).font(.headline).accessibilityIdentifier("assemblyTitle")
                    if let step = model.current {
                        Text(step.text).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("assemblyStep")
                    }
                    HStack {
                        Button("Back") { model.previous() }.disabled(model.isFirst).accessibilityIdentifier("assemblyBack")
                        Spacer()
                        Button("Next step") { model.next() }.disabled(model.isLast).accessibilityIdentifier("assemblyNext")
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: TapTarget.minimum)
                }
                if !model.guide.warnings.isEmpty {
                    Section(titled: "Before you start") {
                        ForEach(model.guide.warnings, id: \.self) {
                            Label($0, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.fails)
                                .accessibilityElement(children: .combine)
                        }
                    }
                }
                Section(titled: "You'll need") {
                    ForEach(model.guide.hardware, id: \.item) {
                        Text("\($0.quantity) × \($0.item)").accessibilityIdentifier("assemblyHardware")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Assemble")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 18.0, *)
private struct AssemblyStage: View {
    let model: AssemblyModel
    @State private var root = Entity()

    static let wood = SimpleMaterial(color: Palette.wood, roughness: 0.75, isMetallic: false)
    static let new = SimpleMaterial(color: .systemGreen, roughness: 0.6, isMetallic: false)

    var body: some View {
        RealityView { content in
            content.add(root)
            let light = DirectionalLight()
            light.light.intensity = 2500
            light.look(at: .zero, from: SIMD3(0.8, 1.5, 1.2), relativeTo: nil)
            // A directional light only needs its direction. Left out at 1.5 m, it would count in the bounds the
            // orbit camera fits to, and the build would be drawn tiny.
            light.position = .zero
            content.add(light)
        } update: { _ in
            root.children.removeAll()
            let framing = StageFraming.fit(model.scene.pieces.map(\.end))
            root.scale = SIMD3(repeating: framing.scale)
            root.position = framing.offset
            for piece in model.preview {
                let pose = piece.end
                let entity = ModelEntity(mesh: .generateBox(width: pose.size.x, height: pose.size.y, depth: pose.size.z,
                                                            cornerRadius: 0.002),
                                         materials: [Self.wood])
                entity.transform = Transform(scale: .one, rotation: pose.rotation, translation: pose.position)
                root.addChild(entity)
            }
            for (piece, isNew) in model.visible {
                let pose = piece.end
                let entity = ModelEntity(mesh: .generateBox(width: pose.size.x, height: pose.size.y, depth: pose.size.z,
                                                            cornerRadius: 0.002),
                                         materials: [isNew ? Self.new : Self.wood])
                entity.transform = Transform(scale: .one, rotation: pose.rotation, translation: pose.position)
                root.addChild(entity)
            }
        }
        .realityViewCameraControls(.orbit)
        .accessibilityLabel("The build so far, in 3D")
        .accessibilityIdentifier("assemblyStage")
    }
}
