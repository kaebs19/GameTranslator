import SwiftUI

/// One tap instead of dragging the box into place.
struct BoxPresetBar: View {
    @Binding var box: ScanBox

    var body: some View {
        HStack(spacing: AppSpacing.small * 2) {
            ForEach(BoxPreset.allCases, content: chip)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private func chip(_ preset: BoxPreset) -> some View {
        let isSelected = BoxPreset.matching(box) == preset
        return Button {
            withAnimation(.snappy(duration: 0.25)) { box = preset.box }
        } label: {
            Text(preset.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Color.white : Color.appTextSecondary)
                .padding(.horizontal, AppSpacing.small)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if isSelected {
                        Capsule().fill(AppGradient.action)
                    } else {
                        Capsule().fill(Color.appSurfaceRaised)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension BoxPreset {
    var title: LocalizedStringResource {
        switch self {
        case .subtitles: .presetSubtitles
        case .dialog: .presetDialog
        case .menu: .presetMenu
        case .full: .presetFull
        }
    }
}
