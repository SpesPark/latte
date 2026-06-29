# Notes for App Store Reviewer

> Pasted into the "App Review Information → Notes" field at submission. Plain English. Anticipates the most common rejection reasons for sleep-prevention utilities.

---

Hello,

This is the initial submission of Latte, a menu bar utility that prevents the Mac from sleeping based on user-configured triggers.

## What the app does

Latte runs in the menu bar and uses `IOPMAssertionCreateWithName` (with assertion type `kIOPMAssertionTypeNoIdleSleep` or `kIOPMAssertionTypeNoDisplaySleep` depending on the user's setting) to prevent the system from sleeping. This is the standard, sandbox-compatible Apple-recommended API for this purpose, identical to what `caffeinate(1)` uses.

## Why Latte exists alongside other "stay awake" apps

Latte's differentiator is automation: rather than requiring the user to remember to toggle the assertion on/off manually, Latte watches five context signals (Calendar events, running apps, current Wi-Fi SSID, a time-of-day schedule, and whether an external display is connected) and decides automatically. The user configures their triggers once and never thinks about it again. This is a meaningful behavioral difference from utilities that only offer a manual toggle.

## Permissions requested

All permissions are requested only when the user enables the corresponding trigger, never at app launch:

- **Calendar (read-only)** — when Calendar trigger is enabled. Used to read upcoming event start/end times. `NSCalendarsFullAccessUsageDescription` in Info.plist explains this to the user at the system prompt.
- **Location Services** — when Wi-Fi trigger is enabled. Required by Apple for `CWWiFiClient.interfaceName` SSID access since macOS 11. Latte does not access geographic location data; only the SSID string. `NSLocationWhenInUseUsageDescription` makes this clear.

## Sandbox

Fully sandboxed (`com.apple.security.app-sandbox = true`). Entitlements:
- `com.apple.security.app-sandbox`
- `com.apple.security.personal-information.calendars`
- `com.apple.security.personal-information.location`

No `com.apple.security.temporary-exception.*` entitlements. The Schedule and External Display triggers require no permission or entitlement at all (time-of-day timer and `CGDisplay` count respectively).

## Privacy

Latte does not collect any user data. There is no analytics SDK, no telemetry, no third-party SDK at all in v1.0. All settings are stored in local UserDefaults. Privacy Policy URL provided in submission.

## How to test the app (suggested smoke for reviewer)

1. Launch the app. Menu bar shows a coffee-cup icon.
2. Click the icon. A dropdown appears with manual duration buttons (15m, 30m, 1h, 2h, Custom, Until off, Settings, Quit).
3. Pick "30m". The cup view animates filling with liquid; menu bar icon may indicate active state. `pmset -g assertions` from Terminal should now show a `NoIdleSleepAssertion` (or `NoDisplaySleep` per user setting) named `Latte`.
4. Click the icon and pick "Turn off". The assertion is released immediately. `pmset -g assertions` no longer shows it.
5. Settings → Triggers → enable "App" trigger. The trigger is set to watch a default list of communication apps if you have them installed (Zoom / Teams / Discord / Slack / Webex / Google Meet); otherwise the list is empty. Add an app you have running (e.g., Safari) using "Add from running apps". The cup activates within ~1 second of adding.
6. Remove the same app from the list. The cup deactivates immediately.
7. (Optional) Settings → Triggers → "External Display": when enabled, Latte stays awake while an external monitor is connected (the built-in display is excluded). Settings → Triggers → "Schedule": stays awake during a user-defined weekday + time-of-day window. Both are pure system-state reads and request no permission.

## What's intentionally NOT in v1.0

- A Focus-mode trigger — reading Focus state from a sandboxed app requires an additional entitlement; it is planned for a future version and is not part of this submission's feature set or metadata.

## Contact

For any questions during review, please reach out to hightempier18@gmail.com — I will respond within 24 hours.

Thank you for reviewing.
