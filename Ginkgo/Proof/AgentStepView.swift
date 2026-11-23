import GinkgoCore
import SwiftUI

/// One step of a planning run, in plain words: a headline, then a line for each problem the checks found.
struct AgentStepView: View {
    let step: AgentStep

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Label(StepWording.headline(step), systemImage: PlanningView.icon(StepWording.shownStatus(step)))
                .foregroundStyle(PlanningView.color(StepWording.shownStatus(step)))
                .font(.subheadline.weight(.semibold))
            ForEach(StepWording.problems(step), id: \.self) { problem in
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.leading, Spacing.large)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("agentStep")
    }
}

/// The run in one sentence, above the steps.
struct StepStoryView: View {
    let trace: [AgentStep]

    var body: some View {
        if let story = StepWording.story(trace) {
            Text(story)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("planStory")
        }
    }
}
