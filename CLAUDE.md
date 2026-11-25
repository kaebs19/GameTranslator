# Game Translator (مترجم ألعاب) — iOS

## What this app does
Translates on-screen text from games (e.g. GTA companion apps, any game) into Arabic using on-device OCR + translation.
No game files are modified. The app only reads what is visible on screen.

## Two modes (both required)
1. **Instant screenshot mode**
   - User takes a screenshot / picks the latest screenshot / uses a Shortcut (Back Tap or Action Button via App Intents) / Share Extension.
   - App runs OCR, translates, and renders the Arabic text over the original image (replace text in place using OCR bounding boxes).
2. **Live / scrolling mode**
   - ReplayKit Broadcast Upload Extension captures frames while the user plays or scrolls.
   - Frames are throttled (~1 fps), de-duplicated (perceptual hash / frame diff), OCR'd, and new lines are appended to a running translated transcript (de-duplicate lines already seen so scrolling does not repeat text).
   - Results are shown in the main app (transcript view), Live Activity, and optional local notifications.

## Hard platform constraints (do not try to work around these)
- iOS cannot draw a floating window over other apps. No overlay on top of the game.
- Broadcast Upload Extension memory limit is ~50 MB. Keep processing light: use Vision `.fast` recognition for live mode, downscale frames, never keep frame history in memory.
- Apple Translation framework (`TranslationSession`) needs a SwiftUI host (`.translationTask`) and does NOT run inside the extension. The extension must pass recognized text to the main app via App Group, and the main app translates.
- Broadcast extension and main app communicate through an **App Group** (shared container + Darwin notifications or shared UserDefaults/files).

## Tech stack
- Swift 6, SwiftUI, minimum iOS 18 (Translation framework). Check availability before using newer APIs.
- OCR: Vision `VNRecognizeTextRequest` (supports English; set `recognitionLanguages` from user setting).
- Translation: Apple Translation framework (on-device). Optional later: pluggable `Translator` protocol with a cloud API fallback (Google / LLM) behind a setting.
- Cache: translate each unique string once (in-memory + persisted dictionary).

## Targets
- `GameTranslator` (main app)
- `BroadcastExtension` (Broadcast Upload Extension)
- `ScreenshotIntents` (App Intents for Shortcuts / Back Tap) — can live in the main app target
- Shared Swift package or folder `Shared/` for models, OCR service, text-dedupe, App Group helpers

## Architecture (MVVM)
- `GameTranslator/App`: entry point, `AppRouter`, and `AppDependencies` (the only place that picks concrete services).
- `GameTranslator/Core`: UI-free services (Translation, Imaging, Photos, Errors).
- `GameTranslator/DesignSystem`: reusable views. Must not import anything from `Features`.
- `GameTranslator/Features/<Name>/{Models,ViewModels,Views}`: one folder per screen.
- `Shared/{Models,OCR,Text,Storage}`: code the broadcast extension also compiles. Mark types `nonisolated`.
- Views hold no business logic. View models are `@Observable`, receive services as protocols through `init`, and never import SwiftUI.
- `Shared/Live`: capture-independent live pipeline (`LumaImage` → `FrameFingerprint` → OCR → `TextDeduper` → `LiveChannel`). `BroadcastExtension` only feeds it frames; the app reads it through `LiveFeed`.
- `LiveActivityShared`: attributes, views and button intents compiled into the app and `LiveActivityExtension`. `LiveActions.handler` is set by `AppDependencies`, so buttons work when iOS launches the app in the background.
- In the background `TranslationService` uses a headless session (iOS 26+, main app only). Before iOS 26 pending text waits until the app is opened.
- UI: dark only. Views use `AppPalette` / `Color.app…`, `AppGradient`, `.card()`, `.buttonStyle(.primary/.secondary/.icon)`, never raw colors. `ThemeTests` checks contrast.
- Tabs: Home (camera + reading box), TV, Connect (guides that open existing features; no console brand names), Settings. Images, live, history and controls open over Home as `HomeSheet`.
- Interface language (system / Arabic / English) is `InterfaceLanguageModel`, applied with `.interfaceLanguage(_:)` on the root **and inside every sheet**; navigation stacks get `.id(language)` because an existing bar keeps its direction.
- Camera: `CameraFrameReader` sends `CameraEvent`s. A frozen picture is kept in memory only, and the image shown comes from the same frame that is read. `OverlayPlacement` keeps the translation off the box. `keepScreenOn` is on only while reading.
- `AppTabBar` replaces the system tab bar; each tab hides the system one.
- `LineMerger` joins wrapped sentences before translation (images, camera, and up to 3 lines in live). It is careful on purpose: never join menu entries.
- `Core/Camera` reads only the box on screen; `CameraPreviewView` converts it to sensor coordinates. Frames are never stored.
- `CloudFallback` runs only after on-device translation failed, the user consented and entered a key. Anything claiming "nothing is uploaded" must follow `usesCloud`.
- `PrivacyPolicyView` and `Docs/privacy-policy.html` carry the same text. Update the privacy manifests when using a new required-reason API.
- ReplayKit broadcast is deprecated in iOS 27 (replaced by ScreenCaptureKit) but is the only option on iOS 18–26.
- `Core/Live/ScreenCapture` is an experimental iOS 27+ source (off by default, device only: the simulator SDK has no ScreenCaptureKit). It needs the `screen-capture` background mode.
- Translation goes through `TranslationProviding`. `TranslationService` queues work for the single `.translationHost(_:)` at the app root.

## Conventions
- UI strings in Arabic first (RTL support), English second. Use String Catalogs.
- No game names, logos or trademarks in app name, icon, or metadata.
- No analytics or network calls by default. Everything on-device unless the user enables cloud translation.
- Privacy: images and frames are never stored unless the user saves a translated image. Text and translations are kept on device in the cache and in History (added on request; can be turned off and cleared).
- Keep functions small, add unit tests for text dedupe and line-merging logic.

## Build & run
- Open the `.xcodeproj` / `.xcworkspace` in Xcode; test on a **real iPhone** (broadcast does not work properly on the simulator).
- CLI build check: `xcodebuild -scheme GameTranslator -destination 'generic/platform=iOS' build`
- Signing and TestFlight upload are done manually by the developer in Xcode. Do not edit signing settings.

## App Store review notes (important)
- Broadcast use must be clearly explained in app description and review notes: "User explicitly starts a screen broadcast to translate on-screen text. Nothing is recorded or uploaded."
- Provide a short demo video for App Review.
- Privacy policy URL required. Data Safety / App Privacy answers must match behavior.
- The app's App Store Connect record already exists (name: مترجم الألعاب). Bundle ID must match it.

## Definition of done for each milestone
Builds without warnings, runs on device, behavior verified by the developer, short note of what changed.
