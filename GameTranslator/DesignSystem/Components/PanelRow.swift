import SwiftUI

/// Rows grouped on one surface, with a title above and a note below.
struct Panel<Content: View>: View {
    let title: LocalizedStringResource
    var note: LocalizedStringResource?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, AppSpacing.small)
            VStack(spacing: 0) { content }
                .card()
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, AppSpacing.small)
            }
        }
    }
}

/// Colored symbol, title, and whatever belongs at the end.
struct PanelRow<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringResource
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            IconTile(icon: icon, tint: tint)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: AppSpacing.small)
            trailing
        }
        .padding(.horizontal, AppSpacing.regular)
        .frame(minHeight: 60)
        .contentShape(.rect)
    }
}

/// Current value with a symbol that says what a tap does.
struct PanelValue: View {
    enum Style: String {
        case menu = "chevron.up.chevron.down"
        case link = "chevron.forward"
    }

    let text: Text?
    let style: Style

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            if let text {
                text
                    .font(.subheadline)
                    .foregroundStyle(Color.appAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Image(systemName: style.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
                .accessibilityHidden(true)
        }
    }
}

struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.appOutline)
            .frame(height: 1)
            // Lines up with the titles, after the symbol.
            .padding(.leading, AppSpacing.regular + IconTile.size + AppSpacing.medium)
    }
}

struct IconTile: View {
    static let size: CGFloat = 34

    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: Self.size, height: Self.size)
            .background(tint.opacity(0.18), in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}
