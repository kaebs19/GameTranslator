# TV receivers

The iPhone app translates and sends text over the home network; these apps draw it.

| TV | Folder | How it draws | Tried on |
|---|---|---|---|
| Android / Google TV (built in) | `android` | Window over everything, HDMI included where the TV allows it | Phone emulator, not over HDMI |
| Samsung (Tizen) | `samsung` | Shows HDMI behind its page (`tizen.tvwindow`) | Never ran on a TV |
| LG (webOS) | `lg` | Shows HDMI in a `<video>` (`ext://hdmi:N`, undocumented) | Page only, in a desktop browser |
| Any browser | `GameTranslator/Resources/TVReceiver.html` | Text only | Desktop browser |

## Build
- Android: `cd android && gradle assembleDebug testDebugUnitTest` (Gradle 9.5, JDK 21 from Android Studio), or open the folder in Android Studio. Install: `adb connect <tv>` then `adb install app/build/outputs/apk/debug/app-debug.apk`. If the TV has no overlay setting: `adb shell appops set com.gametranslator.tv SYSTEM_ALERT_WINDOW allow`.
- Samsung and LG: `./build-web.sh`, then package `dist/samsung` with Tizen Studio (needs a Samsung certificate) and `dist/lg` with the webOS CLI. Both TVs must be in Developer Mode.

Signing and store accounts are the developer's.

## Protocol
- `POST /pair` `{"pin","name"}` → `{"token"}`; 403 wrong PIN, 429 locked.
- `GET /events?token=` → server-sent events. `{"lines":[{"text","original"}],"isRTL","position","size"}` is the whole picture; `{"ping":true}` every 5 s. 401 means the phone removed this TV. After 12 s of silence, clear the text and reconnect.
