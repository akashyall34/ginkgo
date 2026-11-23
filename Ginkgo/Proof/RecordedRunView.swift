import GinkgoCore
import SwiftUI

/// Replays the recorded Gemini run step by step, then opens its plan's proof. Clearly marked as a recording.
struct RecordedRunView: View {
    let run: RecordedRun
    let inventory: Inventory
    @State private var shown = 0

    var body: some View {
        List {
            Section {
                Label(RecordedRun.label, systemImage: "record.circle")
                    .font(.headline)
                    .foregroundStyle(Palette.brand)
                    .accessibilityIdentifier("recordedLabel")
                Text(run.detail).font(.subheadline.monospacedDigit()).foregroundStyle(Palette.secondaryText)
                if shown == run.trace.count { StepStoryView(trace: run.trace) }
            }
            Section("Every step, checked") {
                ForEach(run.trace.prefix(shown), id: \.index) { step in
                    AgentStepView(step: step)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if shown == run.trace.count {
                Section {
                    NavigationLink {
                        ProofView(model: run.proof(inventory: inventory))
                    } label: {
                        Label("See the proof", systemImage: "checkmark.seal").font(.headline)
                            .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                    }
                    .accessibilityIdentifier("seeProof")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.brand)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard shown == 0 else { return }
            for step in run.trace.indices {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeOut) { shown = step + 1 }
            }
        }
    }
}

/// The recorded run on the sample furniture, or a designed state if the files can't be loaded.
struct ExampleRecordedRunView: View {
    var body: some View {
        if let run = RecordedRun.load(), let inventory = Self.sampleInventory() {
            RecordedRunView(run: run, inventory: inventory)
        } else {
            ContentUnavailableView("Recording unavailable", systemImage: "record.circle",
                                   description: Text("The recorded agent run couldn't be loaded."))
        }
    }

    static func sampleInventory(bundle: Bundle = .main) -> Inventory? {
        guard let url = bundle.url(forResource: "inventory", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Inventory.self, from: data)
    }
}
