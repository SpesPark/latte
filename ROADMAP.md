# Latte — Project Roadmap

> Multi-session execution plan for Latte (working folder: `Caffeinated-Clone/`).
>
> **Current phase**: Coverage gate + Phase 1.5 + UX rewrite (S7 → S7.5 → S7.6 → S7.7 → S7.8 → S7.9 → S7.10); 261/261 tests passing
> **Current session**: 7.10 of ~10 (complete) — Per-trigger grace replaces blanket 60 s cool-down; v1 default = immediate sleep on all OFFs (fix-first after S7.9 smoke)
> **Next session entry point**: see [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) — Session 8 = App Store prep (blocked on Dev Program + icon)

---

## Vision

Latte is a macOS menu bar utility that keeps a Mac awake **automatically based on context** (calendar, apps, Wi-Fi, Focus) — solving the "Mac slept mid-Zoom-call" pain that incumbents (Amphetamine, Caffeinated) leave unaddressed.

**Decisions locked** (see `docs/design/01-PRD.md` §12):
- Name: **Latte**
- Min OS: **macOS 13 Ventura**
- Pricing: **$2.99 one-time** (App Store, Small Business 15%)
- Source: **private repo**
- Phase scope: **A (automation) + C (design)** at launch; B (iOS) deferred to Phase 2

---

## Multi-session plan

Each row is one focused session. Sessions are sequential — earlier ones produce inputs for later ones.

| # | Session theme | Goals | Deliverables | Status |
|---|---|---|---|---|
| 1 | **Foundation: PRD + Architecture** | Lock product scope, lock module/layer structure | `01-PRD.md`, `02-architecture.md`, `ROADMAP.md`, `SESSION_HANDOFF.md` | 🟢 Done |
| 2 | **Design close-out** | Resolve all Open Questions before code | `03-state-machine.md`, `04-data-model.md`, sign-off on 01+02 | 🟢 Done |
| 3 | **Phase 1.0 implementation** | Rewrite Sources to match architecture; implement MVP features | All `Sources/**/*.swift`, replaces current skeleton | 🟢 Done |
| 4 | **Phase 1.A — Triggers** | Calendar + App + Wi-Fi + Focus triggers fully implemented | `Sources/Triggers/*.swift`, integration tests | 🟢 Done |
| 5 | **Phase 1.C — Design polish** | Coffee cup animation, Liquid Glass + fallback, app icon spec | UI files, asset catalog updates | 🟢 Done |
| 6 | **Build verification** | First successful build, fix compile errors, run tests | Working `.app` bundle, all tests passing | 🟢 Done |
| 7 | **Test coverage + QA** | ≥80% coverage, manual smoke test on macOS 13/14/15 | Test files, QA log | 🟢 Done |
| 8 | **App Store prep** *(needs Dev Program + icon)* | Metadata, screenshots, Privacy Policy, submission | App Store Connect record, GitHub Pages site | 🟡 Next (blocked on Dev Program + icon) |
| 9 | **TestFlight beta launch** | Beta build, recruit ≥10 testers | TestFlight build, beta feedback log | ⚪ Pending |
| 10 | **Submission + launch** | Address beta feedback, submit to App Store, launch on ProductHunt | App Store live, ProductHunt post | ⚪ Pending |

Status legend: 🟢 done · 🟡 in progress · 🔴 blocked · ⚪ pending

---

## Milestone gates

Decision points where progress halts until a gate is passed.

| Gate | Triggered after | Pass criteria | If fail |
|---|---|---|---|
| **G1: Design sign-off** | Session 2 | Owner reviews PRD + 02 + 03 + 04, accepts all open questions resolved | Iterate on specific doc; do not start code |
| **G2: Architecture validated** | Session 3 | First module compiles; trigger protocol can be mocked in tests | Refactor architecture; revisit 02 doc |
| **G3: MVP feature-complete** | Session 5 | All Phase 1.0 + 1.A + 1.C features tickable on Launch Criteria checklist (PRD §10) | Defer non-essential to Phase 1.5 |
| **G4: Build green** | Session 6 | Tests pass on macOS 14 + 15 CI, no power-assertion leak in 24-hr soak | Fix bugs; do not submit |
| **G5: Beta confidence** | Session 9 | Crash-free ≥99% over ≥2 weeks with ≥10 testers, ≤3 P2 bugs open | Extend beta; do not submit |
| **G6: App Store approved** | Session 10 | Apple review passes | Address rejection; resubmit |

---

## User-side blocking tasks

These cannot be done by the assistant; user must complete on their own time **between sessions**.

| Task | Required by | Estimated effort | Notes |
|---|---|---|---|
| Install Xcode 15+ from App Store | Before session 6 | 30 min download + install | Required for any build |
| Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` | Before session 6 | 1 min | Switch from CLT to Xcode |
| Install XcodeGen (`brew install xcodegen`) | Before session 6 | 1 min | For `project.yml` → `.xcodeproj` |
| Enroll in Apple Developer Program ($99/yr) | Before session 8 | 1~2 days approval | <https://developer.apple.com/programs/> |
| Decide bundle ID prefix (e.g., `com.yourname`) | Before session 8 | — | Replaces `com.example` |
| Design app icon (DIY, hire, or AI) | Before session 8 | Variable | 1024×1024 PNG; Asset Catalog auto-scales |
| (Optional) Register `latte.app` or similar domain | Before session 8 | 10 min | $10~30/yr; not required for launch |
| Set up GitHub Pages site for Privacy Policy + landing | Session 7~8 | 30 min | Template provided in session 8 |
| Recruit ≥10 TestFlight beta testers | Before session 9 | Variable | Twitter/Reddit/personal network |

---

## Context budget per session

Each session targets:
- **Concrete deliverables**: 1~3 files written or substantially edited
- **Review checkpoints**: ≤2 owner-decision moments
- **Wall time**: 1~3 hours (depending on complexity)

Avoiding "kitchen sink" sessions keeps each handoff clean.

---

## Risk-driven schedule adjustments

If risks fire (per PRD §9), the schedule changes:

- **R-01 fires** (Amphetamine adds calendar): compress sessions 3~5, ship Phase 1.A incomplete if needed
- **R-02 fires** (App Store rejects): insert ad-hoc session for rebranding/repositioning
- **R-06 fires** (burnout): pause for ≥1 week, then resume from last completed session

---

## How to read this roadmap in future sessions

When you (the developer) start a new session:

1. Read this file to remember the multi-session plan
2. Open [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) to see exactly where the previous session ended
3. The HANDOFF doc tells you: which file to open, what the next deliverable is, and any blocking decisions

The HANDOFF doc is **always overwritten** at the end of each session. The ROADMAP is the long-lived plan.

---

## Document version

| Version | Date | Notes |
|---|---|---|
| 0.1 | 2026-04-25 | Initial draft (session 1) |
| 0.2 | 2026-04-25 | Session 2 complete; design phase closed; sessions 1–2 marked done, session 3 marked next |
| 0.3 | 2026-04-25 | Session 3 complete; Phase 1.0 code + tests landed; sessions 1–3 done, session 4 marked next |
| 0.4 | 2026-04-26 | Session 4 complete; Phase 1.A trigger real wiring + Source DI pattern + tests; sessions 1–4 done, session 5 marked next |
| 0.5 | 2026-04-26 | Session 5 complete; Phase 1.C design polish — Canvas+TimelineView coffee cup, Liquid Glass card, menu bar icon variants, Settings typography, TriggersTab vote indicator, `05-icon-spec.md`; sessions 1–5 done, session 6 marked next |
| 0.6 | 2026-04-26 | Session 6 complete; first green Xcode build (Xcode 26.4.1) + all 178 tests passing; fixes: `static let` for AppIntent properties, `(1, 1440)` literal for `@Parameter` range, `NSApp.sendAction` fallback for `openSettings` (macOS 13 compat), first-OFF silence semantic for WiFi/Focus triggers (consistent with AppTrigger); sessions 1–6 done, session 7 marked next |
| 0.7 | 2026-04-26 | Session 6 (extended) — post-build smoke surfaced gaps; fixed: `SettingsWindowController` (NSHostingController-based; `Settings { }` scene + `SettingsLink` don't wire reliably for LSUIElement menu-bar apps), espresso-brown accent via `NSColor` dynamic provider (Canvas doesn't resolve `Color.accentColor` / `Color.primary` against current appearance), `Theme.Colors.cupStroke` explicit `NSColor.labelColor`-based dynamic, `DurationPickerRow` hover state + caramel accent bar + dimmed Turn-off, divider opacity 0.5, **custom duration α** (`CustomDurationRow` — inline 1–1440-min Stepper + Start). All 178 tests still pass. |
| 0.15 | 2026-04-26 | Session 7.10 — **Per-trigger grace replaces blanket 60 s cool-down (state machine surgery + UX win)**. Owner re-smoke against S7.9 confirmed Toggle OFF and watched-list edits *do* propagate through the system, but the cup stayed activated for 60 seconds because the state machine always entered `.coolingDown(60s)` on the last vote-off — and `.coolingDown` is `isAwake = true`. To owner that read as "비활성 안됨." Cross-app analysis (Amphetamine, Owly, KeepingYouAwake, Caffeinated, Theine) showed no leading sleep-prevention app uses a hidden cool-down; competitors transition immediately. Combined with the fact that Latte's `.asleep` only releases the IOPMAssertion (macOS still respects its own 5–15 min idle timeout before actually sleeping), the cool-down was largely working invisibly underneath the OS timer with no perceptible benefit. **Fix**: replace the blanket cool-down with **per-trigger grace**. `Trigger` protocol gains `var graceSecondsAfterOff: TimeInterval { get }` (default-impl extension returns 0). `TriggerVote` gains `graceSecondsAfterOff: TimeInterval` (Sendable, default 0). `AwakeInput.triggerVoteOff` extends from `(id: String)` to `(id: String, graceSeconds: TimeInterval)`. `AwakeStateMachine.step` for `(.awakeTriggered, .triggerVoteOff(id, grace))`: when `newVotes.isEmpty`, fork on `grace == 0` → `.asleep` + `.releaseAssertion` (no timer) vs `grace > 0` → existing `.coolingDown` path. `AwakeManager.receiveTriggerVote` extracts grace from vote when forwarding. `TriggerCoordinator.stop` (Toggle OFF path) synthesizes its vote-OFF with grace=0 explicitly — user-explicit actions always bypass the trigger's declared grace. `AppTrigger.reevaluateWatched` does the same on user-driven list edit. `AppTrigger.handleTerminate` (organic) emits with `self.graceSecondsAfterOff` so triggers can opt into a grace period if they ever override the default. **v1: all 4 triggers stay at grace = 0**, so every OFF (Toggle, list edit, app-terminate, calendar-end, WiFi-leave, Focus-off) releases the assertion immediately. Cool-down infrastructure is preserved for future opt-in (e.g., production telemetry surfaces a real WiFi-blip flicker → override `WiFiTrigger.graceSecondsAfterOff: 30`, no state machine surgery needed). 7 test sites updated: §8 worked-example tests for cool-down behavior now pass `graceSecondsAfterOff: 30` explicitly; new tests cover both forks (`testAwakeTriggered_triggerVoteOff_lastVote_grace0_goesToAsleepImmediately` + `testAwakeTriggered_triggerVoteOff_lastVote_gracePositive_goesToCoolingDown`) plus AwakeManager-level integration of `receiveTriggerVote` dispatching grace correctly. The S7.9 owner-scenario integration tests in `TriggerCoordinatorTests` were tightened from "coolingDown OR asleep" to strict "asleep". 255 → 261 tests, all pass. Coverage gate still PASS (AwakeManager 94.26%, AppTrigger 98.62%, TriggerCoordinator 92.96%). `03-state-machine.md` v0.2 documents the new design with full revised rationale; `02-architecture.md` v0.15 §13 captures the architectural surgery. |
| 0.14 | 2026-04-26 | Session 7.9 — **Trigger lifecycle fix: Toggle OFF + watched-list edit (fix-first after S7.8 smoke)**. Owner ran the S7.8 build and confirmed positive cases work (enable → cup activates) but flagged that negative cases were broken: Toggle OFF and remove-app-from-watched-list both left the cup activated indefinitely. Two structural bugs fixed at once. **(A) Toggle OFF only persisted the flag** — `TriggerSection`'s `Toggle.onChange` set `trigger.isEnabled = false` but did nothing to the live trigger. The `WorkspaceObservation` stayed alive, the consumer Task in `TriggerCoordinator` kept forwarding stale ON votes, `awakeManager.pendingVotes` retained the entry, `manager.isAwake` stayed true. Fix: pass `coordinator: TriggerCoordinator` into `TriggerSection`; the Toggle's `onChange` now spawns a `Task { @MainActor in … }` that calls `coordinator.start(trigger)` on ON or `coordinator.stop(trigger.id)` on OFF — and `coordinator.stop` already synthesizes a vote-OFF that flips state out of `.awakeTriggered`. Universal across all 4 triggers (Calendar / App / WiFi / Focus). **(B) AppTrigger captured `watched` once at start()** and froze it into the `onLaunch:` / `onTerminate:` closures, so removing an app from the watched list left the trigger using a stale set: `matchingRunning` retained the un-watched app, no vote-OFF emitted, cup stayed on. Fix: `AppTrigger.watchedSet` is now an instance var (set in `start()`, cleared in `stop()`); `handleLaunch/handleTerminate` simplified to read it; new public `AppTrigger.reevaluateWatched()` reads the latest `settings.appTriggerBundleIDs`, recomputes `matchingRunning`, and emits vote ON/OFF/re-emit-ON-with-fresh-reason on transition. `AppTriggerConfigForm.commit(_:)` calls it after writing settings, so adds/removes propagate within one render pass. **Stream lifecycle hardening**: removed `continuation.finish()` from `AppTrigger.stop()` — finishing the AsyncStream permanently silenced the trigger across any future Toggle OFF → ON cycle. Stream now stays open for the trigger's lifetime; the coordinator cancels its consumer Task on stop, recreates one on start, and the trigger keeps yielding votes from a single long-lived stream. New regression test `testRestartAfterStopReEmitsInitialSnapshot`. 6 new tests total (5 reevaluateWatched + 1 restart-after-stop), `testStopCancelsObservation` comment refreshed for the lifecycle change. 249 → 255 tests, all pass. Coverage gate still PASS (AppTrigger 98.06% — slight drift from 98.89% reflects the new reevaluate branches; well above 80% floor). The same "watched-list mutation doesn't reach the live trigger" pattern likely affects WiFi/Calendar/Focus too — deferred to S7.10 if owner re-smoke surfaces it; the universal Toggle fix already covers "disable this trigger entirely" for all 4. |
| 0.13 | 2026-04-26 | Session 7.8 — **App trigger pickable filter + installed-only seed (fix-first after S7.7 smoke)**. Owner re-smoke against S7.7 surfaced 3 connected complaints: (1) curated defaults pre-populate apps the owner doesn't have installed (creating an unfamiliar list with broken-looking icons), (2) "Add from running apps" Menu items show names without icons, (3) the same Menu lists every running process (system daemons, menu-bar utilities, Latte itself). Fixed at the root rather than cosmetically: `WorkspaceSource` extended with `pickableRunningBundleIDs: [String]` (real impl filters `.regular` activation policy + excludes self via `Bundle.main.bundleIdentifier`) and `isInstalled(_:) -> Bool` (real impl checks `NSWorkspace.urlForApplication(withBundleIdentifier:)`). New `AppTriggerDefaults.installedDefaults(in:)` filters the 6 curated IDs to those installed on the user's machine. New `SettingsKey.hasSeededAppDefaults` Bool flag persists "we've seeded once." `AppTrigger.init` runs `seedInstalledDefaultsIfNeeded()` — once per install — that writes installed-only curated defaults to the watched list and sets the flag (idempotent across re-launches; respects users who explicitly cleared their list). The legacy fallback in `SettingsStore.appTriggerBundleIDs` getter (return all 6 curated IDs when raw is empty) is **removed** — empty now means watch nothing, and seeding is the one place curated defaults populate. UI: TriggersTab Menu uses `pickableRunningBundleIDs`, items render via `Label { Text(name) } icon: { Image(nsImage:) }` with SF Symbol category fallback (`video.fill` for video-call apps, `bubble.left.and.bubble.right.fill` for chat apps); `AppRow` uses the same SF Symbol fallback; empty-state copy refreshed to invite users to add their own apps. New `AppTriggerDefaults.symbolHint(for:)` exposes the category mapping. 14 new tests (symbol hint × 2, isInstalled × 3, installedDefaults × 2, first-launch seed × 4, pickable × 3); `testRequiredKeysExist` extended with the new SettingsKey. 235 → 249 tests, all pass. Coverage gate: AppTrigger 98.89% (up from 98.68% in S7.7); all gated files ≥80%. |
| 0.12 | 2026-04-26 | Session 7.7 — **App trigger UX friendly names (fix-first after S7.6 smoke)**. Owner reported S76-DEF-01: App trigger row showed raw bundle IDs (`us.zoom.xos`) and the trigger had no purpose copy, making it opaque to non-technical users. `WorkspaceSource` protocol gains `displayInfo(for:) -> AppDisplayInfo?` returning a Sendable struct of `displayName` + optional PNG-encoded icon data. `NSWorkspaceSource.displayInfo(for:)` resolves in priority order: **running app** (`NSRunningApplication.localizedName`/`icon`, downsampled to 64pt) → **installed bundle** (`NSWorkspace.urlForApplication(...)` + `Bundle.localizedInfoDictionary`/`infoDictionary` + `NSWorkspace.icon(forFile:)`) → **curated default** (`AppTriggerDefaults.displayName(for:)` table covering Zoom/Microsoft Teams/Webex/Discord/Slack/Google Meet) → `nil`. `MockWorkspaceSource.displayInfoLookup` stubbable for tests; falls through to curated table. `AppTrigger.displayInfo(for:)` is a thin passthrough so SwiftUI never touches the source directly. `AppTriggerConfigForm` rewritten: new `AppRow` view (real icon + display name body line + bundle ID muted caption when distinct), purpose-explaining caption at the top, "Add from running apps" Menu items now use display names (sorted case-insensitively), manual bundle-ID input collapsed under a `DisclosureGroup` labelled "Advanced — add by bundle ID" closed by default (label is non-interactive caption per S7.6 lesson, so DisclosureGroup is safe here). 6 new tests — `AppTriggerDefaults.displayName(for:)` curated mapping + unknown-ID nil, `MockWorkspaceSource.displayInfo` curated fallback + override priority + nil-for-unmapped, `AppTrigger.displayInfo` passthrough. 229 → 235 tests; gate still PASS (AppTrigger 98.68% with adapter+inner-closures excluded). Zero persistence/architecture changes — friendly resolution is purely a render-time concern. |
| 0.11 | 2026-04-26 | Session 7.6 — **TriggersTab UX rewrite (fix-first after S7.5 smoke)**. Owner reported subtitle/Toggle state mismatch ("켜져 있을 때 disabled로 표시되는") + general "복잡하고 직관적이지 않음." Root cause: DisclosureGroup label held both the row HStack and the Toggle, so SwiftUI hit-testing fired the disclosure expand and the Toggle on overlapping click areas; meanwhile `subtitle` read `trigger.isEnabled` (SettingsStore) while the Toggle UI showed `@State var isOn`, so any onChange miss left the two visibly out of sync. Plus the `if newValue { isExpanded = true }` side-effect inside onChange added a second mutation in the same transaction. Rewritten as **Section per trigger** (`Form { ForEach { TriggerSection } }`): each trigger is its own `Section`, with a single standalone `Toggle("Enable")` row (no click-target collision possible), and the per-trigger config form rendered inline below the toggle when `isOn`. Section header carries icon + name + voting dot; section footer carries the live "Voting awake — …" reason or permission-status hint. `subtitle` helper deleted; the Toggle itself is the source of truth for enabled state. `AppTriggerConfigForm` "Add from running apps" was a nested DisclosureGroup — replaced with a `Menu` showing the candidate list as standard macOS dropdown. `WiFi` mode picker upgraded from `.radioGroup` to `.segmented` for clearer two-state choice. `id: \.offset` → `id: \.id` on the outer ForEach for explicit identity. Zero protocol/architecture changes; SwiftUI-only restructure. 229/229 tests still pass; coverage gate still PASS. |
| 0.10 | 2026-04-26 | Session 7.5 — **Phase 1.5.A: per-trigger config UI**. The S5 deferred backlog item lands. `Sources/UI/Settings/TriggersTab` is rewritten around `DisclosureGroup`; tapping a trigger row reveals a per-trigger configuration form: **App** (bundle-ID list + remove + manual add + "Add from running apps" picker fed by `AppTrigger.runningBundleIDs` passthrough), **Wi-Fi** (SSID list + remove + manual add + "Add current network" using `WiFiTrigger.currentSSID` + on/inverse mode picker), **Calendar** (lead/trail steppers 0–15 min + exclude-all-day toggle; the EventKit calendar picker itself is intentionally deferred to a future Phase 1.5.B since it needs live `EKCalendar` listing). **Focus** shows an explanatory paragraph since `INFocusStatusCenter` does not expose stable per-Focus IDs to third parties in v1. New public passthroughs `AppTrigger.runningBundleIDs` + `WiFiTrigger.currentSSID` (both delegate to their `*Source` adapters; tests added). 229/229 pass; coverage gate still PASS (`Triggers/AppTrigger` 98.5%, `Triggers/WiFiTrigger` 96.6%). No architecture-level changes — pure UI + 2 small public-API additions on existing types. |
| 0.9 | 2026-04-26 | Session 7 complete — **coverage + QA gate**. Coverage baseline (`xcodebuild -enableCodeCoverage YES`) + per-file analysis revealed 4 files under 80% (`SettingsStore` 75.2%, `PowerAssertion` 29.6%, `WiFiTrigger` 60.2%, `CalendarTrigger` 52.0%) once live-system adapters were excluded. Closed the gaps: `SettingsStore` 100% (added `double` round-trip + 5 type-mismatch fallback tests), `PowerAssertion` 87.3% (new `Tests/PowerAssertionTests.swift` exercising real `IOPMAssertion*` APIs — promoted off the adapter exemption list since IOKit power assertions need no entitlement), `WiFiTrigger` 96.5% (start/stop lifecycle, `requestPermissionIfNeeded`, isEnabled setter, permissionStatus getter), `CalendarTrigger` 98.8% (start/stop, isEnabled/permissionStatus, typed settings setters). 227/227 tests pass, all gated files ≥80%. New `docs/QA_LOG.md` consolidates the coverage snapshot, owner-side smoke checklist, adapter exemption rationale, and macOS 13/14/15 matrix deferral to TestFlight. |
| 0.8 | 2026-04-26 | Session 6 (extended again) — **coffee tone customization**. New `CoffeeAccent` enum with 5 hand-tuned presets (Espresso / Caramel / Mocha / Latte / Noir), each carrying light + dark sRGB pairs resolved via `NSColor(name:dynamicProvider:)`. Persisted under new `SettingsKey.coffeeAccent`, mirrored on `AppEnvironment.@Published var coffeeAccent`. Settings → General → Appearance gains a Coffee tone Picker with color-dot previews, plus a small `CoffeeCupView` preview at the top of the Appearance section so the user sees the new tone live without leaving the window (the menu-bar popover closes when Settings takes focus). Five views consume `environment.coffeeAccent.color` (`HeaderView`/`CoffeeCupView` liquid, `DurationPickerRow`/`CustomDurationRow` accent bar + checkmark, `GeneralTab` status dot, `TriggersTab` voting indicator, `AboutTab` cup). 17 new tests (12 `CoffeeAccentTests` + 5 `AppEnvironmentTests` for accent ⇄ store mirror); 195/195 pass. |
