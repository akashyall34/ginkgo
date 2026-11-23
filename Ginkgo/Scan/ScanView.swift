import SwiftUI

/// The Scan screen: aim, capture, pick a face, fine-tune its corners, read the size.
struct ScanView: View {
    @State private var model: ScanModel
    @State private var showDepthQuality = true
    @Environment(\.dynamicTypeSize) private var typeSize
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

    /// Always takes its space, so the photo above never shrinks when a measurement is saved.
    private var saveStatus: some View {
        let measured: Bool = { if case .measured = model.status { return true } else { return false } }()
        return Group {
            if measured && model.saveFailed {
                Label("The latest measurement couldn't be saved on this device.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.fails)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("saveFailure")
            } else if measured && model.savedScanID != nil {
                Label("Saved to My items", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Palette.verified)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("saveConfirmation")
            } else {
                Label("Saved to My items", systemImage: "checkmark.circle.fill").hidden().accessibilityHidden(true)
            }
        }
        .font(.footnote)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var unsupported: some View {
        ContentUnavailableView(
            "LiDAR needed",
            systemImage: "sensor",
            description: Text("Ginkgo measures with the LiDAR Scanner on iPhone 12 Pro and later Pro models.")
        )
        .accessibilityIdentifier("unsupported")
    }

    /// Normally everything fits on one screen. At accessibility text sizes the words need more room than a
    /// screen has, so the page scrolls, the photo keeps a fixed, usable height instead of shrinking, and the
    /// capture controls stay pinned at the bottom where a thumb can always reach them.
    @ViewBuilder private var content: some View {
        if typeSize.isAccessibilitySize {
            ScrollView { details(photoHeight: Self.accessibilityPhotoHeight).padding(Spacing.medium) }
                .safeAreaInset(edge: .bottom) {
                    controls.padding(Spacing.medium).background(Palette.background)
                }
                .modifier(ScanLifecycle(model: model))
        } else {
            VStack(spacing: Spacing.medium) {
                details(photoHeight: nil)
                controls
            }
            .padding(Spacing.medium)
            .modifier(ScanLifecycle(model: model))
        }
    }

    static let accessibilityPhotoHeight: CGFloat = 420

    private func details(photoHeight: CGFloat?) -> some View {
        VStack(spacing: Spacing.medium) {
            photoArea
                .frame(height: photoHeight)
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
            saveStatus
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
                    .overlay(Label("Demo scene", systemImage: "cube").foregroundStyle(Palette.secondaryText))
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

/// Starts and pauses the camera with the screen, and plays the result haptics.
private struct ScanLifecycle: ViewModifier {
    let model: ScanModel

    func body(content: Content) -> some View {
        content
            .onAppear { model.source.start() }
            .onDisappear { model.source.pause() }
            .sensoryFeedback(trigger: model.status) { _, new in
                if case .measured = new { return .success }
                if case .problem = new { return .warning }
                return nil
            }
    }
}
