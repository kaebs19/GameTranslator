# App Review notes

Paste the English block into **App Store Connect → App Review Information → Notes**.
Replace every `<...>` first.

---

## Notes for the reviewer (English)

**What the app does.** It reads text that is visible on screen in games (OCR) and translates it, mainly into Arabic. It does not modify, inject into, or access any other app.

**Three modes**

1. *Instant*: the user picks an image or their latest screenshot. Text is recognized with Vision and translated with Apple's Translation framework.
2. *Live*: User explicitly starts a screen broadcast to translate on-screen text. Nothing is recorded or uploaded. The Broadcast Upload Extension downsizes about one frame per second, runs OCR in memory, and discards the frame. Only recognized text is passed to the app through an App Group, and those files are deleted once read.

3. *Camera*: the user points the camera at any screen; text inside a box is recognized in memory and translated. No photo or video is saved or sent.

**How to test Live mode (a real device is required)**

1. Open the app and finish the introduction.
2. *Home* → image button at the top → choose any image containing English text. Accept the language download if iOS asks.
3. *Home* → image button → *Broadcast Phone Screen* → *Start Broadcast* → confirm in the system sheet.
4. Open any app showing English text, for example Safari, and scroll for about 20 seconds.
5. Return to the app. The translated lines are on the broadcast screen.
6. Tap *Stop Broadcast*, or use the red indicator.

**No account is needed.** There are no purchases, ads or analytics.

**Network.** The app makes no network requests by default. *Settings → Cloud Translation* is off. If the user enters their own Google Cloud Translation key and agrees to a consent dialog, recognized text (never images) is sent to Google only when on-device translation fails.

**Background modes**

- `screen-capture` (iOS 27+): used only by the optional "In-App Capture (Experimental)" setting, which keeps a user-started ScreenCaptureKit stream running while the user plays.
- `remote-notification`: <REMOVE THIS MODE BEFORE SUBMITTING, or explain its use. The app does not use it today.>

**Demo video:** <LINK>
**Contact:** <NAME, EMAIL, PHONE>

---

## Demo video script (60–90 seconds, recorded on a real iPhone)

Record with a second camera, or with a Mac through QuickTime: iOS cannot run a screen recording and a broadcast together.

1. Open the app; show the introduction, including the page about the broadcast.
2. Instant mode: choose a screenshot → translated image → switch to the list → Save.
3. Camera mode: point at a screen with text; move the box; the translation appears below.
4. Live mode: *Start Broadcast* → show the system confirmation and the recording indicator.
5. Switch to a game or web page with text; play or scroll.
6. Return: show the translated transcript.
7. Stop the broadcast; the state becomes "stopped".
8. Settings: cloud translation off, privacy policy.

Use a game or page you have the right to show.
