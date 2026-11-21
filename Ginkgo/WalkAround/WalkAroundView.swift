import ARKit
import RealityKit
import SwiftUI

/// Walk around the furniture while the room mesh fills in, then aim the dot at it and tap Done.
struct WalkAroundView: View {
    @State private var model = WalkAroundModel()
    @State private var capture = MeshCapture()

    var body: some View {
        Group {
            if MeshCapture.isSupported {
                scanner
            } else {
                ContentUnavailableView("Needs a LiDAR iPhone", systemImage: "cube.transparent",
                                       description: Text("The walk-around scan uses the LiDAR sensor on iPhone 12 Pro and later."))
            }
        }
        .navigationTitle("Walk around")
        .navigationBarTitleDisplayMode(.inline)
        .background(Palette.background)
    }

    private var scanner: some View {
        VStack(spacing: 0) {
            ZStack {
                MeshPreview(session: capture.session)
                    .ignoresSafeArea(edges: .horizontal)
                    .accessibilityHidden(true)
                if model.status == .scanning {
                    Circle().fill(Palette.brand).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .accessibilityHidden(true)
                }
            }
            panel
        }
        .onAppear { capture.start() }
        .onDisappear { capture.pause() }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if case .measured(let box) = model.status {
                Text(WalkAroundModel.summary(box))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .accessibilityIdentifier("walkAroundResult")
                Text("Width × height × depth").font(.footnote).foregroundStyle(.secondary)
                NavigationLink {
                    LiveProofView(box: box)
                } label: {
                    Label("Make a plan", systemImage: "hammer")
                        .font(.headline)
                        .foregroundStyle(Palette.onBrand)
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand)
                .accessibilityIdentifier("makePlan")
            }
            Text(model.instruction)
                .font(.body)
                .foregroundStyle(model.status == .scanning ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("walkAroundInstruction")
            Button {
                if model.status == .scanning {
                    model.finish(points: capture.furniturePoints(), floorY: capture.floorY(), aim: capture.aimPoint())
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    model.rescan()
                }
            } label: {
                Text(model.status == .scanning ? "Done" : "Scan again")
                    .font(.headline)
                    .foregroundStyle(Palette.onBrand)
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand)
            .accessibilityIdentifier("walkAroundButton")
        }
        .padding(Spacing.medium)
        .background(.regularMaterial)
    }
}

/// The camera with the room mesh drawn over it as it's scanned.
private struct MeshPreview: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session = session
        view.debugOptions.insert(.showSceneUnderstanding)
        view.environment.sceneUnderstanding.options.insert(.occlusion)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}
}
