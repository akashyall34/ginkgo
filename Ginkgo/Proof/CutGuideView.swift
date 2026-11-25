import ARKit
import GinkgoCore
import SwiftUI

/// Mark the cuts, one panel at a time: the drawing, each piece's marks in mm from the panel's edges, and on an
/// AR-capable iPhone, the same lines drawn on the real panel.
struct CutGuideView: View {
    @State private var model: CutGuideModel
    private let plan: Plan
    private let result: ValidationResult

    init(plan: Plan, result: ValidationResult, inventory: Inventory) {
        _model = State(initialValue: CutGuideModel(result: result, inventory: inventory))
        self.plan = plan
        self.result = result
    }

    var body: some View {
        Group {
            if model.isEmpty {
                ContentUnavailableView("No cuts to mark", systemImage: "checkmark.seal",
                                       description: Text("Every panel in this plan is reused whole."))
            } else {
                guide
            }
        }
        .background(Palette.background)
        .navigationTitle("Mark the cuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var guide: some View {
        List {
            Section {
                Text(model.title).font(.headline).accessibilityIdentifier("cutPanelTitle")
                if let sheet = model.sheet { CuttingDiagramView(sheet: sheet) }
                Text("Hold the panel the way it's drawn, with its bottom edge toward you.")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
            }
            Section(titled: "Marks") {
                ForEach(Array(model.steps.enumerated()), id: \.offset) { number, step in
                    Text("\(number + 1). \(step)")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cutStep")
                }
            }
            if ARWorldTrackingConfiguration.isSupported, let panel = model.current {
                Section {
                    NavigationLink {
                        ARCutMarkingView(panel: panel)
                    } label: {
                        Label("Mark with AR", systemImage: "arkit").font(.headline)
                            .frame(minHeight: TapTarget.minimum)
                    }
                    .accessibilityIdentifier("markWithAR")
                }
            }
            Section {
                HStack {
                    Button("Previous panel") { model.previous() }
                        .disabled(model.isFirst)
                        .accessibilityIdentifier("previousPanel")
                    Spacer()
                    Button("Next panel") { model.next() }
                        .disabled(model.isLast)
                        .accessibilityIdentifier("nextPanel")
                }
                .buttonStyle(.borderless)
                .frame(minHeight: TapTarget.minimum)
            }
            Section {
                NavigationLink {
                    CutCheckView(plan: plan, result: result, inventory: model.inventory)
                } label: {
                    Label("Check the cut pieces", systemImage: "checkmark.rectangle.stack").font(.headline)
                        .frame(minHeight: TapTarget.minimum)
                }
                .accessibilityIdentifier("checkCutPieces")
            }
        }
        .scrollContentBackground(.hidden)
        .tint(Palette.brand)
    }
}
