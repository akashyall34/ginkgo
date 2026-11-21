import SwiftUI

/// The Scan screen: aim, capture, pick a face, fine-tune its corners, read the size.
struct ScanView: View {
    @State private var model: ScanModel
    @State private var showDepthQuality = true
    /// When set (from Verify), a measured face can be handed back with "Use this measurement".
    private let onUse: ((QuadResult) -> Void)?

    init(source: FrameSource, onUse: ((QuadResult) -> Void)? = nil) {
        self.onUse = onUse
        _model = State(initialValue: ScanModel(source: source, store: ScanStore.standard(),
                                                 lifter: VisionSubjectLifter()))
    }

    var body: some View {
        Group {
            if model.source.isSupported { content } else { unsupported }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WalkAroundView()
                } label: {
                    Label("Walk around", systemImage: "rotate.3d")
                }
                .accessibilityIdentifier("walkAroundLink")
            }
        }
        .background(Palette.background)
    }

    private var unsupported: some View {
        ContentUnavailableView(
            "LiDAR needed",
            systemImage: "sensor",
            description: Text("Ginkgo measures with the LiDAR Scanner on iPhone 12 Pro and later Pro models.")
        )
        .accessibilityIdentifier("unsupported")
    }

    private var content: some View {
        VStack(spacing: Spacing.medium) {
            photoArea
            MeasurementPanelView(model: model)
            if let onUse, case .measured(let result) = model.status {
                Button {
                    onUse(result)
                } label: {
                    Label("Use this measurement", systemImage: "checkmark")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.verified)
                .accessibilityIdentifier("useMeasurement")
            }
            controls
        }
        .padding(Spacing.medium)
        .onAppear { model.source.start() }
        .onDisappear { model.source.pause() }
        .sensoryFeedback(trigger: model.status) { _, new in
            if case .measured = new { return .success }
            if case .problem = new { return .warning }
            return nil
        }
    }

    @ViewBuilder private var photoArea: some View {
        ZStack {
            if let frame = model.frame {
                FrozenPhotoView(model: model, frame: frame, showDepthQuality: showDepthQuality)
            } else if let session = model.source.previewSession {
                CameraPreview(session: session)
                    .accessibilityLabel("Live camera")
            } else {
                Palette.brand.opacity(0.08)
                    .overlay(Label("Demo scene", systemImage: "cube").foregroundStyle(.secondary))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var controls: some View {
        if model.frame == nil {
            Button { model.capture() } label: {
                Label("Capture", systemImage: "camera.shutter.button")
                    .foregroundStyle(Palette.onBrand)
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand)
            .accessibilityIdentifier("capture")
        } else {
            VStack(spacing: Spacing.small) {
                Toggle("Show depth quality", isOn: $showDepthQuality)
                    .tint(Palette.brand)
                HStack(spacing: Spacing.small) {
                    secondaryButton("Place corners", icon: "square.dashed", id: "placeCorners") {
                        model.placeCornersManually()
                    }
                    secondaryButton("Retake", icon: "arrow.counterclockwise", id: "retake") {
                        model.retake()
                    }
                }
            }
        }
    }

    private func secondaryButton(_ title: String, icon: String, id: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
        }
        .buttonStyle(.bordered)
        .tint(Palette.brand)
        .accessibilityIdentifier(id)
    }
}
