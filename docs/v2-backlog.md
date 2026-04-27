# v2 Backlog

> Items deferred from v1.0 ship. Each entry: discovery context (which session surfaced it), rough scope, and ship gate.
> Created during S8 prep (2026-04-27). Append, never overwrite.

---

## P1 candidates (real UX gaps, defer only because not v1.0-blocking)

### V2-01 — Menu-bar icon does not visualize awake state

- **Surfaced**: S7.11 diagnostic note (after owner reported "활성화가 바로 안돼" for App trigger; integration tests proved activation happens within ~100 ms, so the perceived bug was an absent visual signal).
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

### V2-03 — Per-Focus mode selection

- **Surfaced**: S4 implementation notes; reaffirmed in S7.5 design (`FocusTriggerConfigInfo` shows informational copy only).
- **Blocker**: Apple. `INFocusStatusCenter` does not expose stable third-party Focus identifiers. List-presence semantics are the v1 ceiling.
- **Re-evaluate trigger**: any future macOS release (15.x, 16) that surfaces a stable per-Focus API. Until then, do not invest engineering time.

### V2-04 — EKCalendar list picker (Phase 1.5.B)

- **Surfaced**: S7.5 (`CalendarTriggerConfigForm` shipped without it); also called out in S7-family handoff and SESSION_HANDOFF "Known issues" section.
- **Scope**: live `EKEventStore.calendars(for:)` enumeration + permission flow, multi-select picker UI, persistence as `[String]` of EKCalendar identifiers, `CalendarTrigger` filter applied to the polled events.
- **Effort**: ~4-6 h end to end (incl. permission re-prompt edge case + 6-8 tests).
- **Why deferred**: Calendar trigger ships with lead/trail steppers + exclude-all-day toggle; works correctly across all calendars by default. Picker is a refinement, not a gap.

---

## P2 candidates (cleanup / hygiene)

### V2-10 — Drop `Theme.Colors.accentAwake` static alias

- **Surfaced**: S6 design polish session (and re-noted in S7-family handoff).
- **Current state**: `Theme.Colors.accentAwake` is a 1-line forwarder to `CoffeeAccent.default.color`. Lingers from pre-S6 single-color era.
- **Action**: delete the alias, replace 0-N call sites (likely 0 — fold into S10 cleanup pass).
- **Effort**: <30 min.

### V2-11 — Icon Composer / dark / tinted variants

- **Surfaced**: S7.11 (only single light variant landed). 05-icon-spec §6.1 / §7 lists these as optional follow-ups.
- **Action**: open `icon-master-1254.png` in Icon Composer (Xcode 15+), generate dark + tinted layers, drop into `AppIcon.appiconset/`.
- **Effort**: ~1 h owner-side. Pure cosmetic; not gating ship.

### V2-12 — macOS 13/14/15 matrix smoke

- **Surfaced**: S7. Deferred to S9 (TestFlight beta).
- **Reason**: dev box is macOS 26 Tahoe only. TestFlight gives multi-OS coverage for free via beta testers.
- **Action**: gather feedback from 3-5 beta testers across the 3 prior macOS majors. Triage any P1 surfaced, defer P2/P3.

---

## Won't-do (intentional non-goals)

- **Telemetry / analytics SDK** — PRD §7.4 explicitly forbids in v1; no plan to revisit until justified by support load.
- **iCloud sync of trigger settings** — out of v1 scope; would require CloudKit container + multi-device conflict resolution. Re-evaluate post-v1.0 ship.
- **Cross-device (iOS companion)** — gated on Year-1 net revenue ≥ ₩2,000만 per PRD §6.7. Not even on the v2 list yet.
