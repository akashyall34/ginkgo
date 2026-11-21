import SwiftUI

/// The Scan screen: aim, capture, pick a face, fine-tune its corners, read the size.
struct ScanView: View {
    @State private var model: ScanModel
    @State private var showDepthQuality = true

    init(source: FrameSource) {
        _model = State(initialValue: ScanModel(source: source))
    }

    var body: some View {
        Group {
            if model.source.isSupported { content } else { unsupported }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
