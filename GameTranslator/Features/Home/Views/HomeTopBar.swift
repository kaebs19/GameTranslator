import PhotosUI
import SwiftUI

/// Languages and their state, then images, history and controls.
struct HomeTopBar: View {
    let viewModel: CameraViewModel
    @Binding var pickedItem: PhotosPickerItem?
    let useLatestScreenshot: () -> Void
    let open: (HomeSheet) -> Void
    @State private var showsPicker = false

    var body: some View {
        HStack(spacing: AppSpacing.small * 2) {
            LanguagePill(viewModel: viewModel) { open(.controls) }
            addMenu
            AppButton(.historyTitle, icon: "clock.arrow.circlepath") { open(.history) }
                .buttonStyle(.icon)
            AppButton(.controlsTitle, icon: "slider.horizontal.3") { open(.controls) }
                .buttonStyle(.icon)
        }
        .photosPicker(isPresented: $showsPicker, selection: $pickedItem, matching: .images)
    }

    private var addMenu: some View {
        Menu {
            AppButton(.instantPickPhoto, icon: "photo.on.rectangle") { showsPicker = true }
            AppButton(.instantUseLatest, icon: "iphone.gen3", action: useLatestScreenshot)
            AppButton(.homeLive, icon: "dot.radiowaves.left.and.right") { open(.live) }
        } label: {
            AppLabel(.homeAdd, icon: "photo.badge.plus")
        }
        .buttonStyle(.icon)
    }
}

private struct LanguagePill: View {
    let viewModel: CameraViewModel
    let edit: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            name(viewModel.current.source, hint: .settingsSource)
            Button { Task { await viewModel.swapLanguages() } } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 32, height: 44)
                    .contentShape(.rect)
            }
            .disabled(!viewModel.canSwapLanguages)
            .opacity(viewModel.canSwapLanguages ? 1 : 0.4)
            .accessibilityLabel(Text(.homeSwap))
            name(viewModel.current.target, hint: .settingsTarget)
            LanguageReadinessView(viewModel: viewModel)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .padding(.horizontal, AppSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 44)
        .card(AppRadius.large)
    }

    private func name(_ language: AppLanguage, hint: LocalizedStringResource) -> some View {
        Button(action: edit) {
            Text(verbatim: language.displayName(in: locale))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(hint))
    }
}

/// A dot when ready, a download button when something is missing.
private struct LanguageReadinessView: View {
    let viewModel: CameraViewModel

    var body: some View {
        Group {
            if viewModel.isDownloading {
                ProgressView()
            } else {
                switch viewModel.readiness {
                case .unknown:
                    EmptyView()
                case .ready:
                    symbol("checkmark.circle.fill", .appSuccess, .readinessReady)
                case .downloadable:
                    Button { Task { await viewModel.downloadLanguages() } } label: {
                        symbol("arrow.down.circle.fill", .appWarning, .readinessDownload)
                            .frame(width: 34, height: 44)
                            .contentShape(.rect)
                    }
                case .unsupported:
                    symbol("exclamationmark.circle.fill", .appWarning, .readinessUnsupported)
                }
            }
        }
        .padding(.trailing, AppSpacing.small)
    }

    private func symbol(_ name: String, _ color: Color, _ label: LocalizedStringResource) -> some View {
        Image(systemName: name)
            .font(.body)
            .foregroundStyle(color)
            .accessibilityLabel(Text(label))
    }
}
