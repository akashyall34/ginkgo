import GinkgoCore
import SwiftUI

/// Re-measure what the plan depends on most; the plan turns Verified only when the real numbers pass.
struct VerifyView: View {
    @State private var model: VerifyModel
    @State private var typed: [Int: String] = [:]
    @State private var measuring: Int?

    init(plan: Plan, inventory: Inventory, result: ValidationResult) {
        _model = State(initialValue: VerifyModel(plan: plan, inventory: inventory, result: result))
    }

    var body: some View {
        List {
            Section { banner }
            Section("Measure before cutting") {
                ForEach(model.checks.indices, id: \.self) { checkRow($0) }
            }
            if model.status == .verified {
                Section("Steps") {
                    ForEach(Array(model.plan.steps.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)").accessibilityIdentifier("step")
                    }
                }
                Section("Hardware") {
                    ForEach(model.plan.hardware, id: \.item) { item in
                        Text("\(item.quantity) × \(item.item)").accessibilityIdentifier("hardware")
                    }
                }
            }
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $measuring) { index in
            ScanView(source: FrameSources.makeDefault()) { result in
                let meters = model.checks[index].dimension == .width ? result.width : result.height
                model.record(Double(meters) * 1000, for: index)
                typed[index] = String(format: "%.1f", Double(meters) * 100)
                measuring = nil
            }
        }
    }

    /// One status line: the icon is decoration, the text is what VoiceOver reads and tests find.
    private func statusLine(_ text: String, icon: String, color: Color?) -> some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: icon).foregroundStyle(color ?? .secondary).accessibilityHidden(true)
            Text(text)
                .font(color == nil ? .body : .headline)
                .foregroundStyle(color ?? .primary)
                .accessibilityIdentifier("verifyStatus")
        }
    }

    @ViewBuilder private var banner: some View {
        switch model.status {
        case .pending(let remaining):
            statusLine("\(remaining) to measure before this plan is verified", icon: "ruler", color: nil)
        case .verified:
            statusLine("Verified: the real measurements fit", icon: "checkmark.seal.fill", color: Palette.verified)
        case .withdrawn(let reasons):
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                statusLine("Withdrawn: don't cut", icon: "xmark.octagon.fill", color: Palette.fails)
                ForEach(reasons, id: \.self) { Text($0).font(.footnote) }
            }
        }
    }

    private func checkRow(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Text(model.title(of: index)).font(.headline)
                Spacer()
                if model.measured[index] != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.verified).accessibilityLabel("Measured")
                }
            }
            if let planned = model.planned(index) {
                Text(String(format: "Plan assumes %.1f cm", planned / 10)).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.small) {
                TextField("Tape, cm", text: binding(for: index))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: TapTarget.minimum)
                    .onSubmit { submit(index) }
                    .accessibilityIdentifier("tape-\(index)")
                Button("Use") { submit(index) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: TapTarget.minimum)
                    .accessibilityIdentifier("use-\(index)")
                Button { measuring = index } label: { Label("Measure", systemImage: "viewfinder") }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.brand)
                    .frame(minHeight: TapTarget.minimum)
                    .accessibilityIdentifier("measure-\(index)")
            }
        }
        .padding(.vertical, Spacing.xSmall)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(get: { typed[index] ?? "" }, set: { typed[index] = $0 })
    }

    private func submit(_ index: Int) {
        let text = (typed[index] ?? "").replacingOccurrences(of: ",", with: ".")
        guard let centimeters = Double(text) else { return }
        model.record(centimeters * 10, for: index)
    }
}
