# TestFlight and App Review checklist

## Blocks the upload
- [x] **App icon**: 1024×1024, opaque, in `AppIcon.appiconset`.
- [ ] **Bundle ID** matches the App Store Connect record. Today: `com.gametranslator` (extensions: `.BroadcastExtension`, `.LiveActivityExtension`; App Group unchanged: `group.com.gametranslator.GameTranslator`). If it changes, also change both extension IDs (they must start with the app's ID), the test target, and `APP_GROUP_ID`.
- [ ] **Signing** for three targets: `GameTranslator`, `BroadcastExtension`, `LiveActivityExtension`.
- [ ] **App Group** registered and enabled for `GameTranslator` and `BroadcastExtension`.
- [ ] Same version and build number in all three targets.
- [ ] Build with an Xcode version App Store Connect accepts (not a beta).

## Likely review problems
- [ ] The TV tab is a placeholder. App Review rejects unfinished screens: build it or hide it first.
- [ ] `UIBackgroundModes: remote-notification` and the Push entitlement (`aps-environment`) come from the Xcode template and are unused. Unused background modes are a known rejection reason (guideline 2.5.4).
- [ ] `UIBackgroundModes: screen-capture` is used only by the experimental iOS 27 capture. If that feature is not shipping, remove both.
- [ ] The setting labelled "Experimental" is fine for TestFlight, but guideline 2.2 does not want beta features on the App Store: either remove it or, once it works, drop the label.
- [ ] Privacy policy is online and its URL is in App Store Connect. Source: `Docs/privacy-policy.html` (fill in the contact and date first).
- [ ] Review notes and demo video ready: `Docs/APP_REVIEW_NOTES.md`.
- [ ] Description explains the broadcast: `Docs/APP_STORE_LISTING.md`.
- [ ] The icon is an original controller, but its four button colors and positions (yellow top, red right, green bottom, blue left) match a well-known console. Consider other colors.
- [ ] No game names or logos in the name, icon, keywords, screenshots or video.

## App Privacy answers (App Store Connect)
Must match behavior. Decide these yourself; the suggestions follow the code as written.
- [ ] Tracking: **No**.
- [ ] Data collection: the app has no server and no analytics. Suggested: **Data Not Collected**.
- [ ] Cloud translation sends recognized text to Google, only after consent, under the user's own key. Check Apple's current definition of "collect" and Google's retention terms. If in doubt, declare *Other User Content*, not linked to identity, for App Functionality.
- [ ] The privacy manifests (`PrivacyInfo.xcprivacy` in the app and `BroadcastExtension`) declare no collected data. Update them if you answer differently.

## Export compliance
- [ ] The app's own encryption use is HTTPS and the Keychain. Answer the question in App Store Connect, or set `ITSAppUsesNonExemptEncryption` yourself.

## Test on a real iPhone
### Instant
- [ ] First launch shows the introduction once; Settings shows it again.
- [ ] Photos permission: full, limited, denied.
- [ ] First translation offers the language download; airplane mode works afterwards.
- [ ] Portrait and landscape screenshots are readable.
- [ ] Save, share, list view.
- [ ] Shortcut from Shortcuts, Back Tap and Action Button, with the app closed and open.

### Camera
- [ ] Permission: allow, deny, then allow in iPhone Settings.
- [ ] **The box reads exactly what it frames**, in portrait and in both landscape directions, after moving, resizing and zooming.
- [ ] TV and computer screens: text is read despite flicker; try from 1, 2 and 3 meters.
- [ ] Start/stop, edit box, single-shot mode, flashlight, zoom, swapping languages.
- [ ] **The screen stays on** while translating on a stand for 5 minutes, and locks normally after stopping.
- [ ] Box presets frame the right part; the status under the box is right (reading, move closer, no text).
- [ ] Freeze: the held picture equals what is read; moving the box reads again; turning the phone ends it.
- [ ] Full screen in both orientations; the translation never hides the box or the button.
- [ ] Language download from the top bar; the mark turns green; airplane mode works afterwards.
- [ ] Read aloud in Arabic while a game plays sound nearby; copy.
- [ ] History: entries from camera, images and broadcast; search, filter, delete, clear, turning it off.
- [ ] The camera indicator goes off when leaving the tab or the app.

### Smart merging
- [ ] Two-line subtitles are translated as one sentence; menu entries stay separate.

### Live (broadcast)
- [ ] Start and stop from the app and from the system indicator.
- [ ] Two minutes in portrait and in landscape; text is right and not repeated when scrolling.
- [ ] 15 minutes: in Console.app filter `Memory`; stays under 40 MB.
- [ ] Pause, resume, clear.
- [ ] A Japanese or Korean game language shows the explanation instead of the button.

### Live Activity and notifications
- [ ] Appears when a broadcast starts; updates when returning to the app; ends when stopped.
- [ ] Buttons work on the Lock Screen and in Dynamic Island.
- [ ] Translate button works in the background (iOS 26+, language downloaded).
- [ ] Notifications: allow, deny, tap opens Live.

### In-app capture (iOS 27, experimental)
- [ ] Frames keep arriving after leaving the app (Console: `capture`).
- [ ] Translation arrives while playing.

### Cloud translation
- [ ] Wrong key is rejected with a clear message and is not saved.
- [ ] Right key: an unsupported language pair translates.
- [ ] Turning it off deletes the key; nothing is sent afterwards.

### General
- [ ] Arabic and English, largest text size, VoiceOver, iPad.
- [ ] iOS 18 device if available.

## TV
- [ ] iPhone and TV on the same Wi-Fi: pairing with the code, wrong code, five wrong codes (locked 30 s).
- [ ] A real line from the camera reaches the TV; pausing clears it; locking the phone clears it within 12 s; reopening reconnects.
- [ ] Text at the top is not read back by the camera.
- [ ] Android/Google TV (built in): overlay over a real HDMI game, HDR and game mode, after standby.
- [ ] Samsung: HDMI picture and sound inside the app, input lag acceptable.
- [ ] LG: HDMI picture inside the app (undocumented, may fail), otherwise text only.
- [ ] Before release: the receiver apps must be obtainable, or remove their guides from the TV tab.
