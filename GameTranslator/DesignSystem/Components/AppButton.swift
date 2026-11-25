import SwiftUI

/// Button with a localized title and optional icon. Style it with `.buttonStyle` as usual.
struct AppButton: View {
    private let title: LocalizedStringResource
    private let icon: String?
    private let role: ButtonRole?
    private let isWide: Bool
    private let action: () -> Void

    init(
        _ title: LocalizedStringResource, icon: String? = nil, role: ButtonRole? = nil,
        isWide: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.role = role
        self.isWide = isWide
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            if let icon {
                AppLabel(title, icon: icon, isWide: isWide)
            } else {
                Text(title).frame(maxWidth: isWide ? .infinity : nil)
            }
        }
    }
}
