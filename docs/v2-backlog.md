# v2 Backlog

> Items deferred from v1.0 ship. Each entry: discovery context (which session surfaced it), rough scope, and ship gate.
> Created during S8 prep (2026-04-27). Append, never overwrite.
>
> **S8b research reshuffle (2026-04-27)**: Q3 trigger-priority research (Reddit, KYA GitHub issues, Amphetamine reviews, MacRumors) reordered post-v1.0 ship. Headline finding: visual menu-bar state (V2-01) is a **15-year category-standard UX gap** validated by KYA Issue #57; time-of-day/schedule trigger (V2-05, new) shows higher demand than EKCalendar list picker (V2-04). Per-Focus selection (V2-03) is confirmed-low-demand and stays deferred. Full research record: `memory/project_latte_session8b_research.md`.

**v1.0 expansion (S8b, 2026-04-27)**: owner approved "ship aggressively" — V2-01, V2-04, V2-10 promoted into v1.0 alongside two new features (Launch at Login, first-run onboarding wizard). v1.1+ ship order updated below.

**Shipped in v1.0** (originally in this backlog, no longer deferred):
- ✅ **V2-01** menu-bar awake visualization → commit `05f8c2d`
- ✅ **V2-04** EKCalendar list picker → commit `7decb84`
- ✅ **V2-10** `Theme.Colors.accentAwake` cleanup → commit `05f8c2d`

**Shipped in v1.0** (NEW, not previously backlog'd):
- ✅ Launch at Login (SMAppService) → commit `6109859`
- ✅ First-run onboarding wizard (3-step picker) → commit `2da1f3d`

**Recommended ship order** (post v1.0):

| Window | Item | Rationale |
|---|---|---|
| v1.1 | **V2-05** Time-of-day / schedule trigger (NEW) | Highest unmet demand after V2-01 ships in v1.0 |
| v1.1 | Keyboard shortcut for manual toggle | Power-user signal; deferred from v1.0 |
| v1.2 | **V2-06** External display trigger (NEW) | Lightweight, validated demand (KYA #235) |
| v1.2 | **V2-11** Icon dark/tinted variants | Owner-side Icon Composer pass; cosmetic polish |
| v1.x | **V2-02** Calendar/WiFi watched-list immediate-edit | Polling cycle ≤60s makes it tolerable |
| v1.x | **V2-12** macOS 13/14/15 matrix smoke | Surfaced via TestFlight beta in S10 |
| defer | **V2-03** Per-Focus selection | Apple API limit + confirmed-low-demand |

---

## P1 candidates (real UX gaps, defer only because not v1.0-blocking)

### V2-01 — Menu-bar icon does not visualize awake state — ✅ **shipped in v1.0** (commit `05f8c2d`)

- **Surfaced**: S7.11 diagnostic note (after owner reported "활성화가 바로 안돼" for App trigger; integration tests proved activation happens within ~100 ms, so the perceived bug was an absent visual signal).
- **S8b research validation (2026-04-27)**: KYA Issue #57 ("really not as clear as caffeine") + KYA #192 (display remaining time) directly demand this. Caffeine's 15-year-old full-cup/empty-cup is the de facto standard. Promoted to v1.1 must-have.
- **Current behavior**: `MenuBarExtra("Latte", systemImage: ...)` is bound to the user-selected icon style only (`MenuBarIconStyle` enum: filled/outline/clock). It does not reflect `manager.isAwake`. Owner can only verify activation by opening the popover.
- **v2 design sketch**:
  - Approach A: introduce a paired "awake variant" SF Symbol per style (e.g., `cup.and.saucer.fill` ↔ `cup.and.saucer.fill` with a small filled-dot accessory; or swap to a steaming-cup glyph).
  - Approach B: tint the existing symbol via `accessibilityLabel` + `.symbolRenderingMode(.palette)` switching foreground color when awake.
  - Approach C: add a tiny "○ / ●" accessory next to the symbol via `Label`-style composition (richer, but only macOS 14+ has the icon-composition API).
- **Decision needed before build**: which approach. A is simplest; C is most readable; B is most lightweight.
- **Ship gate for v2**: visual diff verified across all 3 icon styles + both light/dark menu bar.

### V2-02 — Calendar/WiFi watched-list edits not immediate

- **Surfaced**: S7.9 follow-up; deferred at end of S7-family review.
- **Current behavior**: AppTrigger picked up `reevaluateWatched()` so config-form edits flow into live votes within one render pass. Calendar (60 s polling) and WiFi (30 s polling) do not — owner must wait one polling cycle for an add/remove to take effect.
- **v2 fix**: add `reevaluateWatched()` to `CalendarTrigger` and `WiFiTrigger` mirroring the `AppTrigger` shape. Wire to the corresponding `*ConfigForm.commit(_:)` methods.
- **Effort**: ~2 h each (new method + 4-5 tests + ConfigForm wiring + QA_LOG note).
- **Why deferred**: owner did not surface in S7.10 smoke; no concrete user complaint yet. Polling cycle is short enough (≤60 s) that it's not painful.

### V2-03 — Per-Focus mode selection — **deferred (confirmed low demand)**

- **Surfaced**: S4 implementation notes; reaffirmed in S7.5 design (`FocusTriggerConfigInfo` shows informational copy only).
- **Blocker**: Apple. `INFocusStatusCenter` does not expose stable third-party Focus identifiers. List-presence semantics are the v1 ceiling.
- **S8b research validation (2026-04-27)**: Q3 research confirmed zero verbatim user requests for per-Focus selection across Reddit, KYA issues, Amphetamine reviews, MacRumors. Latte's binary list-presence approach is acceptable to users.
- **Re-evaluate trigger**: any future macOS release (15.x, 16) that surfaces a stable per-Focus API. Until then, do not invest engineering time.

### V2-04 — EKCalendar list picker — ✅ **shipped in v1.0** (commit `7decb84`)

- **Surfaced**: S7.5 (`CalendarTriggerConfigForm` shipped without it); also called out in S7-family handoff and SESSION_HANDOFF "Known issues" section.
- **Scope**: live `EKEventStore.calendars(for:)` enumeration + permission flow, multi-select picker UI, persistence as `[String]` of EKCalendar identifiers, `CalendarTrigger` filter applied to the polled events.
- **Effort**: ~4-6 h end to end (incl. permission re-prompt edge case + 6-8 tests).
- **Why demoted to v1.3** (S8b research): Q3 research showed time-of-day trigger (V2-05) has higher demand than calendar picker. Picker is a refinement for users with multiple mixed calendars (work + personal); does not move the needle for the median user. Calendar trigger already differentiates Latte from Amphetamine without it.

### V2-05 — Time-of-day / schedule trigger — **NEW, v1.2 ship target**

- **Surfaced**: S8b research (2026-04-27). Q3 trigger-priority study found this is the **second-highest unmet demand** after V2-01.
- **User signal**:
  - KYA Issue #189: *"Would it be possible to add a scheduler? I'd like to leave it activated during the day, but allow sleep at night automatically for example."*
  - KYA Issue #161: separate scheduler request.
  - MacRumors thread #2405685: *"have my Mac awake from 10:15 am until 10:45 am so my mac can run it's calendar automation scripts."*
  - Amphetamine ships time-of-day triggers — table stakes for the power-user segment.
- **Scope (sketch)**:
  - New `ScheduleTrigger: Trigger` conforming to existing `Trigger` protocol.
  - Config: weekday mask (Mon–Sun checkboxes) × time range (start–end pickers) × multiple ranges per day.
  - Persistence: `[ScheduleEntry]` in SettingsStore (JSON-encoded array).
  - Vote loop: every 30 s `currentDate ∈ enabledRanges → vote(.awake)`.
  - UI: new `ScheduleTriggerConfigForm` modeled on `CalendarTriggerConfigForm`.
- **Effort**: ~6-8 h end to end (new trigger type + config form + 8-10 tests + QA_LOG).
- **Ship gate**: 30-day stress test (no leaked timers, range crossing midnight handled, DST transitions handled).

### V2-06 — External display connected trigger — **NEW, v1.3+ ship target**

- **Surfaced**: S8b research (2026-04-27). KYA Issue #235; also Amphetamine ships it.
- **User signal**: laptop-at-desk workflow — *"plugged into monitor → keep awake"* is a real pattern, especially for MacBook Air/Pro users who close the lid.
- **Scope**: monitor `NSScreen.screens` count via `NSApplication.didChangeScreenParametersNotification`; vote `.awake` when external display present.
- **Effort**: ~3-4 h (new trigger + 4-5 tests).
- **Why deferred to v1.3+**: lower demand than V2-05; not v1.0-blocking; potentially overlaps with closed-lid power assertions which need careful interaction with macOS lid-close-sleep policy.

---

## P2 candidates (cleanup / hygiene)

### V2-10 — Drop `Theme.Colors.accentAwake` static alias — ✅ **shipped in v1.0** (commit `05f8c2d`)

- **Surfaced**: S6 design polish session (and re-noted in S7-family handoff).
- **Original state**: `Theme.Colors.accentAwake` was a 1-line forwarder. Confirmed 0 call sites in source/tests at S8b.
- **Outcome**: alias deleted; no migration needed.

### V2-11 — Icon Composer / dark / tinted variants

- **Surfaced**: S7.11 (only single light variant landed). 05-icon-spec §6.1 / §7 lists these as optional follow-ups.
- **Action**: open `icon-master-1254.png` in Icon Composer (Xcode 15+), generate dark + tinted layers, drop into `AppIcon.appiconset/`.
- **Effort**: ~1 h owner-side. Pure cosmetic; not gating ship.

### V2-12 — macOS 13/14/15 matrix smoke

- **Surfaced**: S7. Deferred to S9 (TestFlight beta).
- **Reason**: dev box is macOS 26 Tahoe only. TestFlight gives multi-OS coverage for free via beta testers.
- **Action**: gather feedback from 3-5 beta testers across the 3 prior macOS majors. Triage any P1 surfaced, defer P2/P3.

---

---

## Pending owner-revisit (decided as default in S8, may change later)

### V2-20 — Bundle ID prefix revisit

- **Decided in S8 (2026-04-27)**: `com.parkbyeongjun.latte` as default reverse-DNS based on owner's name.
- **Why deferred**: owner asked to ship with a sensible default and revisit later. No domain ownership was required for the default choice.
- **When to revisit**: before App Store Connect record creation (Phase E). Once submitted to App Store, bundle ID is **immutable** for the app's lifetime — Apple does not allow renaming. Final lock-in is at submission.
- **Alternatives considered**:
  - `com.hightempier.latte` — based on owner's gmail handle. Reasonable nickname-style.
  - `com.bjpark.latte` / `kr.bjpark.latte` — shorter; needs owner-controlled domain (`bjpark.com` / `bjpark.kr`) to be defensible.
  - `app.latte.mac` / `com.latte.app` — needs owner to buy `latte.app` or `latte.com` domain (`latte.app` is currently registered; `.app` TLD requires HTTPS).
- **Action when revisiting**: re-run the same sweep done in S8 — `project.yml` (3 spots), `Sources/Core/{Logging,PowerAssertion,SettingsStore}.swift` (3 spots), `docs/design/{01-PRD,02-architecture,04-data-model}.md`, `docs/QA_LOG.md`, `docs/site/privacy.html`, `docs/store/*-url.txt`. Single grep: `grep -rn "com.parkbyeongjun.latte" .`. Re-run `xcodegen generate` + full test suite.

### V2-21 — Git author identity revisit

- **Decided in S8 (2026-04-27)**: `git config --global user.email "hightempier18@gmail.com"` + `git config --global user.name "박병준"`.
- **Why deferred**: owner asked to ship with a sensible default and revisit later. Past S7-family commits (8 commits, `8592098`..`f1888dc`) plus the docs-only `87d1eab` remain authored under the system `parkbyeongjun@bagbyeongjun-ui-MacBookAir.local` username — **not rewritten** because rewriting published commit history is destructive and out of scope.
- **When to revisit**: before first push to a public GitHub repo (Phase B1 deployment, or earlier if owner wants to push the private repo to GitHub). For App Store Connect, the git author has no impact — Apple only cares about the App Store Connect account email + the developer team.
- **Action when revisiting**: just re-run `git config --global user.email <new>` + `git config --global user.name <new>`. Future commits pick it up; past commits stay as-is.

### V2-22 — GitHub Pages URL / hosting revisit

- **Decided in S8 (2026-04-27)**: `bj-park` GitHub username + `latte` repo name. URLs default to `https://bj-park.github.io/latte/` and `https://bj-park.github.io/latte/privacy.html`.
- **Why deferred**: owner asked to ship with a sensible default and revisit later. The actual `bj-park/latte` repo on GitHub has not been created yet — these URLs are aspirational until Phase B1 GitHub Pages setup runs.
- **When to revisit**:
  - Before App Store submission (Phase E). The Privacy URL **must** return HTTP 200 at App Store submission — verify with `curl -sI <url>` immediately before submitting.
  - If owner wants to split site into a separate `latte-site` repo (cleaner separation; `docs/site/README.md` Option B describes this).
  - If owner buys a custom domain (e.g., `latte.app`, `getlatte.app`) — update `docs/site/CNAME` (create new), update DNS, update `docs/store/{support,marketing,privacy}-url.txt`.
- **Action when revisiting**: sweep `bj-park` and `latte` references the same way as V2-20 — files involved are `docs/site/README.md`, `docs/store/{support,marketing,privacy}-url.txt`. The HTML in `docs/site/index.html` + `privacy.html` does not embed the URL itself, so they don't need touching unless adding a `<link rel="canonical">` tag for SEO.

---

## Won't-do (intentional non-goals)

- **Telemetry / analytics SDK** — PRD §7.4 explicitly forbids in v1; no plan to revisit until justified by support load.
- **iCloud sync of trigger settings** — out of v1 scope; would require CloudKit container + multi-device conflict resolution. Re-evaluate post-v1.0 ship.
- **Cross-device (iOS companion)** — gated on Year-1 net revenue ≥ ₩2,000만 per PRD §6.7. Not even on the v2 list yet.
