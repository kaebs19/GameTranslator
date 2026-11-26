import SwiftUI

/// Switch with a colored symbol, for use inside a `Panel`.
struct PanelToggle: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringResource
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: AppSpacing.medium) {
                IconTile(icon: icon, tint: tint)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
            }
        }
        .tint(AppPalette.brandViolet.color)
        .padding(.horizontal, AppSpacing.regular)
        .frame(minHeight: 60)
    }
}
