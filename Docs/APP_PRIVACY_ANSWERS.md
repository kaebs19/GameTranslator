# App Privacy answers (App Store Connect → App Privacy)

Updated 2026-11-26 for the optional enhanced translation (SubGG server). Check again before each submission if behavior changes.

## Do you or your third-party partners collect data from this app?
**Yes.** Only when the user turns on *Enhanced Translation*, which is off by default. Apple counts data sent off the device as collected even when it is optional.

## Data types

| Type in App Store Connect | Collected? | Why |
|---|---|---|
| **User Content → Other User Content** | Yes | Text read from the screen in camera mode, sent to translate it. Never images. |
| **Identifiers → Device ID** | Yes | The anonymous random token the app registers with the server, used for the daily limit. It is not the advertising identifier or any Apple identifier. |
| Contact info, location, health, financial, contacts, browsing, search, purchases, usage data, diagnostics | No | Not collected by the app. |

The contact form on subgg.app collects an optional name and email, but that is the website, not the app, so it is not declared here (it is in the privacy policy).

## For each collected type

| Question | User Content | Device ID |
|---|---|---|
| Purposes | **App Functionality** | **App Functionality** |
| Linked to the user's identity? | **No** | **No** |
| Used for tracking? | **No** | **No** |

## Notes
- Google Cloud Translation with the user's own key: the text goes to Google under the user's own Google account and key. Apple asks about data that *you or your partners* collect; declaring User Content above already covers text leaving the device.
- Images and camera frames: never collected (read in memory and dropped).
- Privacy policy URL: https://subgg.app/privacy/
- Support URL: https://subgg.app/contact/
