import Foundation

/// Storage shared between the app and (from Milestone 2) its broadcast extension.
nonisolated enum AppGroup {
    /// Comes from the `APP_GROUP_ID` build setting, so it is defined in one place.
    static let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? ""

    /// `nil` when the build is not signed with the App Group capability.
    static var containerURL: URL? {
        guard !identifier.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Falls back to standard defaults so the app still works without the capability.
    static var defaults: UserDefaults {
        guard containerURL != nil, let shared = UserDefaults(suiteName: identifier) else { return .standard }
        return shared
    }
}
