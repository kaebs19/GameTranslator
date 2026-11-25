import SwiftUI

/// Full-width bar attached to the bottom edge.
struct AppTabBar<Tab: Hashable>: View {
    struct Item: Identifiable {
        let tab: Tab
        let title: LocalizedStringResource
        let icon: String
        var id: Tab { tab }
    }

    let items: [Item]
    @Binding var selection: Tab
    @Namespace private var highlight
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Sideways, height is scarce: title beside the symbol.
    private var isCompact: Bool { verticalSizeClass == .compact }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, content: button)
        }
        .padding(.top, isCompact ? AppSpacing.small : AppSpacing.medium)
        .padding(.bottom, AppSpacing.small)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { background }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    private func button(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            withAnimation(.snappy(duration: 0.25)) { selection = item.tab }
        } label: {
            let layout = isCompact
                ? AnyLayout(HStackLayout(spacing: AppSpacing.small))
                : AnyLayout(VStackLayout(spacing: AppSpacing.small))
            layout {
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.appTextSecondary)
                    .frame(width: 64, height: 34)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(AppGradient.action)
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        }
                    }
                Text(item.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.appTextPrimary : Color.appTextSecondary)
                    .lineLimit(1)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var background: some View {
        UnevenRoundedRectangle(topLeadingRadius: AppRadius.large, topTrailingRadius: AppRadius.large)
            .fill(Color.appSurface)
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: AppRadius.large, topTrailingRadius: AppRadius.large)
                    .strokeBorder(Color.appOutline, lineWidth: 1)
            }
            // Runs under the home indicator, and to both edges sideways.
            .ignoresSafeArea(edges: [.bottom, .horizontal])
    }
}
