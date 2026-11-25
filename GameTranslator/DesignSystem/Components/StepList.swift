import SwiftUI

/// Numbered instructions.
struct StepList: View {
    let steps: [LocalizedStringResource]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                    Text(index + 1, format: .number)
                        .font(.headline)
                        .foregroundStyle(.tint)
                    Text(step)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
