import SwiftUI

/// The judge walkthrough on the sample furniture, in the order of the pitch, with a reset so
/// every judge sees the same run. Works without internet: nothing here calls Gemini.
struct DemoView: View {
    enum Step: String, CaseIterable, Identifiable {
        case measure, contrast, agent, proof, transform
        var id: String { rawValue }

        var title: String {
            switch self {
            case .measure: return "1. Measure it"
            case .contrast: return "2. Chatbot vs Ginkgo"
            case .agent: return "3. AI suggests, code decides"
            case .proof: return "4. Proven to fit"
            case .transform: return "5. Transform and AR"
            }
        }

        var detail: String {
            switch self {
            case .measure: return "LiDAR, one tap or walk around"
            case .contrast: return "Same furniture, same validator"
            case .agent: return RecordedRun.label
            case .proof: return "Every cut, the sag check, the cutting plan"
            case .transform: return "The furniture becomes something new"
            }
        }

        var icon: String {
            switch self {
            case .measure: return "viewfinder"
            case .contrast: return "exclamationmark.triangle"
            case .agent: return "sparkles"
            case .proof: return "checkmark.seal"
            case .transform: return "cube.transparent"
            }
        }
    }

    /// Closes the demo when it was opened from Home; nil when the app was launched straight into it.
    var onClose: (() -> Void)?
    @State private var path: [Step] = []
    /// Changing it rebuilds every screen from scratch.
    @State private var run = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack(path: $path) {
            List(Step.allCases) { step in
                NavigationLink(value: step) {
                    // Icon beside the words normally; above them at accessibility sizes, so the words get the width.
                    let row = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.medium))
                    row {
                        Image(systemName: step.icon).foregroundStyle(Palette.brand).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.headline)
                            Text(step.detail).font(.subheadline).foregroundStyle(Palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: TapTarget.minimum)
                }
                .accessibilityIdentifier("demo-\(step.rawValue)")
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Demo")
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .measure: ScanView(source: FrameSources.makeDefault())
                case .contrast: ExampleContrastView()
                case .agent: ExampleRecordedRunView()
                case .proof: ExampleProofView()
                case .transform: ExampleTransformView()
                }
            }
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", action: onClose).accessibilityIdentifier("demoClose")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        path = []
                        run += 1
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .accessibilityIdentifier("demoReset")
                }
            }
        }
        .id(run)
        .tint(Palette.brand)
    }
}
