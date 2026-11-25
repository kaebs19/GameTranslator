import SwiftUI

/// Edit box, start or stop, hold the picture.
struct HomeControls: View {
    let viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: AppSpacing.large * 1.5) {
            RoundControl(
                title: viewModel.isEditingBox ? .homeBoxDone : .homeBoxEdit,
                icon: viewModel.isEditingBox ? "checkmark" : "crop",
                isOn: viewModel.isEditingBox, action: viewModel.toggleEditingBox
            )
            PlayButton(viewModel: viewModel)
            RoundControl(
                title: viewModel.isFrozen ? .homeUnfreeze : .homeFreeze, icon: "snowflake",
                isOn: viewModel.isFrozen, action: viewModel.toggleFreeze
            )
        }
        .frame(maxWidth: .infinity)
        .disabled(viewModel.state != .running)
        .opacity(viewModel.state == .running ? 1 : 0.4)
    }
}

struct PlayButton: View {
    static let size: CGFloat = 68

    let viewModel: CameraViewModel

    var body: some View {
        Button(action: viewModel.toggleTranslating) {
            Image(systemName: viewModel.isTranslating ? "stop.fill" : "play.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.size, height: Self.size)
                .background(AppGradient.action, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 3) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(viewModel.isTranslating ? .homeStop : .homeStart))
    }
}

private struct RoundControl: View {
    let title: LocalizedStringResource
    let icon: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isOn ? Color.appBackground : Color.appTextPrimary)
                    .frame(width: 50, height: 50)
                    .background(isOn ? Color.appAccent : Color.appSurfaceRaised, in: .circle)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .frame(width: 84)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
