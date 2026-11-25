import SwiftUI

/// One of a few large options side by side.
struct ChoiceCard: View {
    let icon: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.appAccent : Color.appTextSecondary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.appAccent : Color.appOutline)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .padding(AppSpacing.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isSelected ? Color.appSurfaceRaised : Color.appSurface, in: .rect(cornerRadius: AppRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .strokeBorder(
                        isSelected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.appOutline),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
