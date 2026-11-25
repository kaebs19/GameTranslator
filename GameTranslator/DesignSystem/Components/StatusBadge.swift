import SwiftUI

/// Colored dot with a short state, for example "Broadcast running".
struct StatusBadge: View {
    let title: LocalizedStringResource
    let isActive: Bool

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Circle()
                .fill(isActive ? .green : .secondary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(title)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
