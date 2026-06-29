# App Store review response — resubmission #1

> Reply for the App Store Connect **Resolution Center**, answering the rejection
> of Submission **dc78a591-c4b8-46b3-b7ef-001f37fcb244** (reviewed 2026-06-23,
> version 1.0 build 1). Paste the "Reply" block below into Resolution Center,
> then upload the new build (1.0.0 **build 2**) and resubmit.
>
> All four issues are addressed in **build 1.0.0 (2)**. See the per-issue notes
> for what changed and where.

---

## Reply (paste into Resolution Center)

Hello, and thank you for the detailed review.

We have addressed all four points in the new build (version 1.0.0, build 2) and
updated the App Store metadata. Details below, in the order raised.

**Guideline 5.2.5 — Intellectual Property (app name / subtitle).**
We have removed the term "Mac" from the app name and subtitle.
- App name: "Latte - Keep Mac Awake" → **"Latte - Keep Awake"**
- Subtitle: "Auto keep-awake for your Mac" → **"Automatic keep-awake utility"**
The metadata no longer uses terms that could be confused with an Apple product.

**Guideline 4 — Design (pop-up truncated at the bottom).**
Thank you for the screenshot. The menu-bar pop-up previously had no height limit,
so on displays with less vertical space its lower options could run off-screen.
In build 2 the pop-up now caps its height to the available screen height and makes
the middle section scroll, while the "Settings…" and "Quit" controls are pinned to
a fixed footer that is always visible and clickable regardless of screen size or
how many options are listed.

**Guideline 2.1(a) — App Completeness (app disappeared after onboarding).**
We identified and fixed this. The app is a menu-bar app (LSUIElement, no Dock
icon), so its only interface is the menu-bar icon. The previous build hid the
menu-bar icon while the onboarding window was open and re-inserted it when
onboarding finished; that re-insertion could fail, leaving the app running with
no visible interface. In build 2 the menu-bar icon is always present — it is shown
from launch and never removed — so the app always has a visible, interactive
surface. The onboarding window simply appears on top of the already-visible icon.

**Guideline 2.1 — Information Needed (sleep-prevention API).**
1. **API:** `IOPMAssertionCreateWithName` (IOKit power management). This is the
   same sandbox-compatible API used by Apple's `caffeinate(1)`.
2. **Assertion type / what we prevent:** depending on the user's setting, either
   `kIOPMAssertionTypeNoDisplaySleep` (prevents display sleep, which also keeps
   the system awake) or `kIOPMAssertionTypeNoIdleSleep` (prevents system idle
   sleep while allowing the display to sleep). The user chooses which in Settings;
   we never prevent more than the user selected.
3. **Create / release + crash cleanup:** we create the assertion when the user
   turns keep-awake on (manually picking a duration, or a context trigger the
   user enabled activating), and we release it (`IOPMAssertionRelease`) as soon as
   keep-awake ends — the user turns it off, the chosen duration elapses, or all
   triggers turn off. Cleanup is guaranteed even if the app crashes: IOPMAssertion
   assertions are a per-process kernel resource, so macOS automatically releases
   all of the app's assertions when the process terminates for any reason. In
   addition we install SIGINT/SIGTERM handlers that release the assertion on exit,
   and the assertion owner's `deinit` releases it as well. The system is never left
   awake after Latte quits.

Please let us know if any further detail would help. Thank you for reviewing.

---

## What changed in build 2 (engineering notes, not for ASC)

| Guideline | Change | Where |
|---|---|---|
| 5.2.5 | Name → "Latte - Keep Awake"; subtitle → "Automatic keep-awake utility" (no "Mac") | `docs/store/app-name.txt`, `subtitle-en.txt`, `subtitle-ko.txt`; **enter in ASC** |
| 4 | Pop-up height capped + scrollable middle; Settings/Quit pinned footer | `Sources/UI/MenuBar/MenuBarLayout.swift`, `MenuBarRoot.swift` (+ `MenuBarLayoutTests`) |
| 2.1(a) | Menu-bar `MenuBarExtra` always inserted (no onboarding gating) | `Sources/App/LatteApp.swift` |
| 2.1 | API answers above; verified against code | `Sources/Core/PowerAssertion.swift`, `AwakeManager.installSignalHandlers` |
| — | Build number 1 → 2 (required for re-upload) | `project.yml` `CURRENT_PROJECT_VERSION` |

## Owner resubmission checklist

1. In **App Store Connect → App Information / the 1.0 version page**, change:
   - **Name** → `Latte - Keep Awake`
   - **Subtitle** → `Automatic keep-awake utility`
   (English (US) only — KO is not yet submitted. `subtitle-ko.txt` is updated for
   when KO is added.)
2. **Archive + upload build 1.0.0 (2)** from Xcode (Product ▸ Archive → Distribute
   ▸ App Store Connect ▸ Upload; Automatic signing, Team `4BXCVHZANL`). Same local
   Archive flow as before — not Xcode Cloud.
   - ⚠ If Xcode dirties `Resources/Localizable.xcstrings` on open/build, revert it
     (`git checkout -- Resources/Localizable.xcstrings`) — it is auto-extraction
     churn, not a real change (S55 gotcha).
3. Select the new build on the version page.
4. Paste the **Reply** block above into Resolution Center.
5. **Add for Review** / resubmit.
