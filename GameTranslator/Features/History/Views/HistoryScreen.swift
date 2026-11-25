import SwiftUI

struct HistoryScreen: View {
    @State private var viewModel: HistoryViewModel
    @State private var confirmsClear = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: HistoryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .appScreenBackground()
                .navigationTitle(Text(.historyTitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .confirmationDialog(Text(.historyClearQuestion), isPresented: $confirmsClear, titleVisibility: .visible) {
                    AppButton(.historyClear, role: .destructive, action: viewModel.clear)
                }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isEmpty {
            ContentUnavailableView {
                AppLabel(.historyEmpty, icon: "clock.arrow.circlepath")
            } description: {
                Text(.historyEmptyHint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.days) { day in
                Section {
                    ForEach(day.entries) { HistoryRow(entry: $0, remove: viewModel.remove) }
                } header: {
                    Text(day.date, format: .dateTime.day().month(.wide).weekday(.wide))
                }
                .listRowBackground(Color.appSurface)
            }
        }
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(.historySearch))
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            AppButton(.commonDone) { dismiss() }
        }
        if !viewModel.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker(selection: $viewModel.source) {
                        AppLabel(.historyAll, icon: "tray.full").tag(HistoryEntry.Source?.none)
                        ForEach(HistoryEntry.Source.allCases, id: \.self) {
                            AppLabel($0.title, icon: $0.icon).tag(HistoryEntry.Source?.some($0))
                        }
                    } label: {
                        Text(.historyFilter)
                    }
                    AppButton(.historyClear, icon: "trash", role: .destructive) { confirmsClear = true }
                } label: {
                    AppLabel(.historyFilter, icon: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let remove: (HistoryEntry) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: entry.source.icon)
                .foregroundStyle(Color.appAccent)
                .accessibilityLabel(Text(entry.source.title))
            TranslatedTextRow(original: entry.original, translation: entry.translation)
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize()
        }
        .swipeActions {
            AppButton(.languagesRemove, icon: "trash", role: .destructive) { remove(entry) }
        }
        .contextMenu {
            AppButton(.historyCopy, icon: "doc.on.doc") { UIPasteboard.general.string = entry.translation }
            ShareLink(item: "\(entry.translation)\n\(entry.original)")
            AppButton(.languagesRemove, icon: "trash", role: .destructive) { remove(entry) }
        }
    }
}

extension HistoryEntry.Source {
    var title: LocalizedStringResource {
        switch self {
        case .camera: .historyCamera
        case .photo: .historyPhoto
        case .live: .historyLive
        }
    }

    var icon: String {
        switch self {
        case .camera: "camera.viewfinder"
        case .photo: "photo"
        case .live: "dot.radiowaves.left.and.right"
        }
    }
}
