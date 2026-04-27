# App Privacy declaration (App Store Connect questionnaire)

> Source-of-truth for the "App Privacy" section of App Store Connect. The questionnaire format is Apple's; answers below are derived from the Privacy Policy in `docs/site/privacy.html` and PRD §7.4.

## Summary answer

**Data collection: NONE.**

Latte does not collect any data from the user. Tick the "We do not collect data from this app" option at the top of the App Privacy questionnaire. App Store Connect will then skip all the data-type sub-sections.

## Justification (paste into the optional explanation field if Apple asks)

Latte runs entirely on-device. It does not include any analytics SDK, telemetry library, or third-party tracking code. It does not make any network requests to any server (Latte's developer does not operate any servers). All user settings are stored in local UserDefaults and never transmitted.

The app accesses the following platform APIs only when the corresponding feature is enabled by the user:

- EventKit (Calendar trigger) — read-only access to upcoming event start/end times. Event data is used in-process only and is never persisted or transmitted by Latte.
- NSWorkspace (App trigger) — running-application list, used in-process to decide whether a watched app is currently running.
- CoreWLAN (Wi-Fi trigger) — current SSID, used in-process to compare against the user's configured SSID list.
- INFocusStatusCenter (Focus trigger) — boolean "is any Focus mode active." No specific Focus identifier is exposed by Apple to third parties.

None of the above results in data leaving the device.

## If Apple's reviewer pushes back

If a reviewer asserts that EventKit / NSWorkspace / CoreWLAN access constitutes "data collection" for the questionnaire, the correct interpretation per Apple's "Data Used to Track You" definition (developer.apple.com/app-store/app-privacy-details/) is:

- Tracking = linking data with data from other companies' apps/websites for advertising or sharing with data brokers.
- Collection = transmitting data off-device.

Latte does neither. Read-in-process-and-discard is not collection under Apple's definition. We are confident in declaring "We do not collect data from this app" and have justification ready.

If a reviewer still insists on the collection declaration, the next-most-accurate answer is:

| Data type | Linked to user? | Used to track? | Purpose |
|---|---|---|---|
| Diagnostics — Crash Data | No | No | App Functionality (only via Apple's opt-in "Share With App Developers" channel — Latte itself does not collect crash data) |

Even this row is debatable since Latte does not initiate the crash-data flow; Apple does, after explicit user opt-in in System Settings → Privacy & Security → Analytics & Improvements. Stick with "We do not collect" unless directly required to change.
