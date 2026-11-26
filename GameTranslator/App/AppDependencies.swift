import UIKit
import UserNotifications

/// Composition root: the only place that picks concrete services.
final class AppDependencies {
    let router = AppRouter.shared
    let interface = InterfaceLanguageModel()
    let translationService: TranslationService
    /// Lives as long as the process: Live Activity buttons use it without any view.
    let liveViewModel: LiveViewModel
    let tvLink: TVLink
    private let notificationTaps: NotificationTapHandler
    private let notifications: any NotificationProviding
    private let cache: TranslationCache
    private let settings: any SettingsStoring
    private let recognizer: any TextRecognizing
    private let photos: any PhotoLibraryProviding
    private let history: HistoryStore
    private let keys: any KeyStoring = KeychainKeyStore()
    private let cloudTranslator: any CloudTranslating = GoogleCloudTranslator()
    private let refiner: ServerRefiner

    init() {
        cache = TranslationCache()
        settings = UserDefaultsSettingsStore()
        history = HistoryStore(settings: settings)
        recognizer = OCRService(mode: .accurate)
        refiner = ServerRefiner(server: SubGGClient(), settings: settings, cache: cache)
        photos = SystemPhotoLibrary()
        notifications = SystemNotificationService()
        translationService = TranslationService(
            cache: cache,
            cloud: CloudFallback(translator: cloudTranslator, keys: keys, settings: settings)
        )
        liveViewModel = LiveViewModel(
            feed: Self.makeFeed(settings: settings), translator: translationService, settings: settings,
            activity: SystemLiveActivityController(), notifications: notifications, history: history,
            isAppActive: { UIApplication.shared.applicationState == .active }
        )
        tvLink = TVLink(
            server: TVServer(page: Self.receiverPage), addresses: SystemLocalAddress(),
            keys: KeychainKeyStore(account: "pairedTVs"), settings: settings
        )
        notificationTaps = NotificationTapHandler { AppRouter.shared.open(.live) }
        // Both must be in place before launch finishes, or a tap that started the app is lost.
        UNUserNotificationCenter.current().delegate = notificationTaps
        LiveActions.handler = liveViewModel
    }

    private static func makeFeed(settings: any SettingsStoring) -> any LiveFeed {
        let broadcast = AppGroupLiveFeed()
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27, *), supportsScreenCapture {
            return SwitchingLiveFeed(broadcast: broadcast, inApp: ScreenCaptureFeed(), settings: settings)
        }
        #endif
        return broadcast
    }

    private static var receiverPage: Data {
        Bundle.main.url(forResource: "TVReceiver", withExtension: "html").flatMap { try? Data(contentsOf: $0) } ?? Data()
    }

    private static var supportsScreenCapture: Bool {
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27, *) { return ScreenCaptureSession.isAvailable }
        #endif
        return false
    }

    func makeInstantTranslateViewModel() -> InstantTranslateViewModel {
        InstantTranslateViewModel(
            translator: translationService,
            recognizer: recognizer,
            photos: photos,
            settings: settings,
            history: history
        )
    }

    func makeHistoryViewModel() -> HistoryViewModel { HistoryViewModel(store: history) }

    func makeCloudSettingsViewModel() -> CloudSettingsViewModel {
        CloudSettingsViewModel(store: settings, keys: keys, translator: cloudTranslator)
    }

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(
            camera: SystemCamera(), translator: translationService, languages: translationService,
            speaker: SystemSpeaker(), settings: settings, history: history, tv: tvLink, refiner: refiner,
            readableLanguages: recognizer.readableLanguages,
            keepScreenOn: { UIApplication.shared.isIdleTimerDisabled = $0 }
        )
    }

    func makeTranslationResultViewModel(_ result: TranslationResult) -> TranslationResultViewModel {
        TranslationResultViewModel(result: result, photos: photos)
    }

    func makeTVViewModel() -> TVViewModel { TVViewModel(link: tvLink, store: settings) }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            store: settings,
            catalog: SystemLanguageCatalog(),
            readableLanguages: recognizer.readableLanguages,
            notifications: notifications,
            supportsScreenCapture: Self.supportsScreenCapture,
            clearCache: { [cache] in await cache.clear() }
        )
    }
}
