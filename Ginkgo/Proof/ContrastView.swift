import SwiftUI

/// The same furniture planned two ways, both checked by the same validator:
/// a plain chatbot's plan in red, Ginkgo's in green.
struct ContrastView: View {
    enum Side: String, CaseIterable, Identifiable {
        case chatbot = "Chatbot"
        case ginkgo = "Ginkgo"
        var id: String { rawValue }
    }

    let chatbot: ProofModel
    let ginkgo: ProofModel
    @State private var side: Side = .chatbot

    var body: some View {
        VStack(spacing: 0) {
            Picker("Plan", selection: $side) {
                ForEach(Side.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.medium)
            .accessibilityIdentifier("contrastPicker")
            Text(side == .chatbot ? "A chatbot's cut list, checked against the real measurements."
                                  : "Ginkgo's plan: built from the measurements, then proven.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .accessibilityIdentifier("contrastCaption")
            ProofView(model: side == .chatbot ? chatbot : ginkgo)
                .id(side)
        }
        .navigationTitle("Chatbot vs Ginkgo")
        .navigationBarTitleDisplayMode(.inline)
        .background(Palette.background)
    }
}

/// The contrast on the sample furniture, or a designed state if the samples can't be loaded.
struct ExampleContrastView: View {
    var body: some View {
        if let chatbot = ProofModel.example(chatbot: true), let ginkgo = ProofModel.example() {
            ContrastView(chatbot: chatbot, ginkgo: ginkgo)
        } else {
            ContentUnavailableView("Example unavailable", systemImage: "doc.questionmark",
                                   description: Text("The sample plans couldn't be loaded."))
        }
    }
}

/// The plan for what was just measured, or why there isn't one.
struct LiveProofView: View {
    let box: FittedBox
    @State private var scanID = UUID().uuidString

    var body: some View {
        switch LivePlan.proof(from: box, scanID: scanID) {
        case .success(let model):
            ProofView(model: model)
        case .failure(let failure):
            ContentUnavailableView("No bench fits", systemImage: "ruler", description: Text(failure.explanation))
                .accessibilityIdentifier("noPlan")
        }
    }
}
