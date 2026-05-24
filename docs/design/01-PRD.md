# 01 — Product Requirements Document (PRD)

| Field | Value |
|---|---|
| **Product name** | Latte |
| **Working folder** | `Latte/` (renamed from `Caffeinated-Clone/` in S8 ahead of App Store submission) |
| **Bundle identifier** | `com.parkbyeongjun.latte` (default — owner may revisit per `docs/v2-backlog.md` V2-20) |
| **Document version** | 0.4 |
| **Status** | Approved (design phase closed at session 2; v1.0 scope re-expanded at S8b) |
| **Owner** | Project owner |
| **Last updated** | 2026-04-27 |
| **Related docs** | [02-architecture.md](02-architecture.md), [03-state-machine.md](03-state-machine.md), [04-data-model.md](04-data-model.md) |

---

## 1. Executive Summary

**Latte** is a macOS menu bar utility that keeps a Mac awake — but unlike incumbents, it does so **automatically based on context** (calendar events, running apps, Wi-Fi network, Focus mode) rather than requiring the user to remember to toggle it.

**One-line pitch**: *"Your Mac stays awake when you need it. Sleeps when you don't."*

**Primary differentiator vs incumbents (Amphetamine, Caffeinated, KeepingYouAwake)**: **Context-aware automatic activation** — Latte reads Calendar events, running apps, Wi-Fi network, and Focus mode to decide. Calendar awareness is the headline proof point because no incumbent ships it; the broader claim is "Latte just knows" so the user never has to remember a toggle.

**Marketing headline (S8 research-driven, 2026-04-27)**: *"Never let your Mac sleep at the wrong moment."* Sub-headline: *"Latte stays awake automatically — for meetings, presentations, downloads, or wherever your day takes you."* Rationale recorded in `memory/project_latte_session8b_research.md`: users articulate the pain as outcome ("Mac slept during my Zoom") rather than mechanism ("calendar-aware").

**Distribution**: Mac App Store, **$2.99 one-time purchase** (Apple Small Business Program 15% take rate). Aggressive entry pricing — owner explicitly chose $2.99 over the $3.99 sweet spot identified in S8b research to undercut Caffeinated ($3.99) and beat Lungo ($4.99) on price while staying above "free" comparisons. Source code is **private**.

**Subscription ban (durable guardrail)**: Latte will **not** ship a subscription tier. Recurring revenue is incompatible with this category — the Bartender 5 (2024) backlash is the canonical cautionary tale. Free-tier + one-time IAP for advanced triggers may be revisited post v1.5 once review base ≥ 50.

**v1.0 scope expansion (S8b, 2026-04-27)** — owner asked to ship aggressively after S8b market research. Five additions on top of the original v1.0 plan:
1. **Menu-bar awake-state visualization** (V2-01, was v1.1) — paired SF Symbol per icon style; the cup visibly fills when active. Closes a 15-year category-standard UX gap (KYA Issue #57).
2. **EKCalendar list picker** (V2-04, was v1.3) — multi-select picker so users restrict the trigger to specific calendars instead of "all granted." Strengthens the headline Calendar wedge.
3. **`accentAwake` cleanup** (V2-10, was v1.x) — dead-code alias removed.
4. **Launch at Login** (NEW) — `SMAppService.mainApp` wrapper exposed via Settings → General → Behavior. Standard menu-bar utility expectation.
5. **First-run onboarding wizard** (NEW) — 3-step picker (welcome → trigger cards → confirm). Persists `firstRunCompleted` in `SettingsKey`. Day-1 retention insurance.

---

## 2. Problem Statement

### 2.1 The user pain

> "I'm in a Zoom call and my Mac goes to sleep mid-meeting. I share my screen and the lid clicks shut. Every. Single. Time."
>
> "I always forget to turn Amphetamine on before a call, and I always forget to turn it off after. So my battery dies overnight."

### 2.2 Why existing solutions are insufficient

| Competitor | Limitation |
|---|---|
| **Amphetamine** (free) | Manual toggle. Some app/process triggers but no calendar integration. UI dated. |
| **KeepingYouAwake** (free, OSS) | Pure manual toggle. No automation. No iOS extension path. |
| **Caffeinated** ($2.99) | Pure manual toggle with timer. No automation. |
| **Caffeine** (legacy, free) | Discontinued, broken on Apple Silicon. |
| **Lungo** ($4.99) | Manual toggle. No calendar/app awareness. |

**Gap**: No mainstream menu-bar utility activates **automatically based on calendar events**. Calendar is the most defensible part of Latte's wedge; the full wedge is **multi-source context-awareness** (Calendar + App + WiFi + Focus combined), positioned via outcome marketing ("never miss a meeting") rather than mechanism marketing ("calendar-aware").

### 2.3 Market trend tailwinds

- Hybrid/remote work normalized → 5+ video calls/day is common
- macOS calendar API matured (`requestFullAccessToEvents` in macOS 14)
- AppIntents/Shortcuts adoption growing → users expect automation
- Apple Focus modes encourage app-as-context-aware

---

## 3. Target Users

### 3.1 Primary persona — "Sarah, the Hybrid PM"

| Attribute | Value |
|---|---|
| **Role** | Project Manager, B2B SaaS, 100~500-person company |
| **Age** | 28~42 |
| **Mac usage** | MacBook Pro/Air, primary device, 8~10 hr/day |
| **Work pattern** | 5~8 video calls/day, screen sharing 30%+, frequently presents |
| **Tools** | Zoom, Microsoft Teams, Google Meet, Calendar (Google or Outlook), Notion, Slack |
| **Tech savvy** | Comfortable with menu bar apps, installs ~5~10 utilities, doesn't write Shortcuts |
| **Key frustration** | Mac sleeps mid-meeting. Has to remember to toggle Amphetamine. Forgets to toggle off → battery drain overnight. |
| **Budget** | Will pay $2~5 for utility that "just works". Skeptical of subscriptions for utilities. |

### 3.2 Secondary personas (not optimized for, but supported)

- **Developer running long builds** — uses CLI, prefers Shortcuts, tolerates Amphetamine
- **Creator rendering video** — uses Final Cut/Logic, single-app trigger pattern
- **Casual user** — wants pure manual toggle, doesn't care about triggers (Latte still works for them)

### 3.3 Anti-persona (explicitly NOT a target user)

- **Power user who lives in Hammerspoon/BetterTouchTool** — they will write their own scripts
- **iOS/iPadOS-only user** — Phase 1 is macOS-only

### 3.4 Job-to-be-done (JTBD)

> When I'm about to start a video call or rendering session, I want my Mac to **automatically stay awake without me thinking about it**, so I can focus on the call/work without worrying about display sleep or battery state.

---

## 4. Goals & Non-Goals

### 4.1 Goals (in priority order)

1. **Reliable keep-awake** — Mac never sleeps when Latte's awake state is active. (Table stakes.)
2. **Zero-thought automation** — User configures triggers once; never toggles manually for routine use cases.
3. **Calendar-first** — Calendar event detection is the headline feature; everything else is bonus.
4. **Beautiful & quiet** — App is delightful when interacted with, invisible when idle. No nag screens, no telemetry prompts, no upgrade pressure.
5. **App Store passable** — Sandboxed, minimal permissions, polished metadata. Approved on first review.
6. **Sustainable for 1-person maintenance** — ≤8 hr/month maintenance after launch.

### 4.2 Non-Goals (explicitly out of scope)

- **iOS / iPadOS / Watch app** — Phase 2 only, after macOS launch validates demand.
- **Cloud sync of settings** — Phase 2 only.
- **Multi-user / team features** — never.
- **Telemetry / analytics** — never. Latte is local-first.
- **In-app purchases / subscriptions** — never. Latte is one-time $2.99.
- **Custom keyboard shortcuts (global hotkeys)** — Phase 1.5 if requested, not at launch.
- **Hammerspoon-style scripting API** — out of scope. Use AppIntents instead.
- **Statistics / "you stayed awake X hours"** — out of scope; risks privacy concern.
- **Battery-aware behavior** ("auto-disable below 20%") — Phase 1.5 nice-to-have.
- **Schedule-based activation** ("every weekday 9am-6pm") — covered by calendar trigger if user puts it on calendar; explicit scheduler is Phase 2.

---

## 5. Success Metrics (KPI)

### 5.1 Year 1 targets (12 months from App Store launch)

| Metric | Pessimistic | **Target (Realistic)** | Stretch |
|---|---|---|---|
| Lifetime downloads (paid) | 500 | **3,000** | 15,000 |
| Net revenue (KRW, after Apple 15%) | ₩178만 | **₩1,067만** | ₩5,337만 |
| App Store rating | 4.0★ | **4.5★** | 4.7★ |
| Crash-free sessions | 99.0% | **99.5%** | 99.9% |
| % users with ≥1 trigger enabled | 20% | **40%** | 60% |
| 30-day retention (active in menu bar) | 50% | **70%** | 85% |
| Median support tickets/week | 5 | **2** | 0 |
| ProductHunt rank (launch day) | top 20 | **top 10** | top 3 |

### 5.2 Leading indicators (week-by-week, post-launch)

- Daily downloads (App Store Connect)
- App Store impression → product-page → download conversion
- Calendar permission grant rate (telemetry-free; inferred from support feedback only)
- Refund rate (target: <2%)

### 5.3 What we explicitly do NOT measure

- Awake duration per user (privacy)
- Trigger activation counts (privacy)
- App-usage patterns (privacy)

All metrics come from App Store Connect or user-reported feedback. **No in-app telemetry in v1.**

---

## 6. Feature Scope

### 6.1 Scope tiers

```
Phase 1.0 (MVP)              ← Build & validate core
  ├─ Phase 1.A (Automation)  ← Differentiation
  ├─ Phase 1.C (Design)      ← Polish & ProductHunt
  └─ Phase 1.QA              ← Launch prep
─────────── App Store launch ───────────
Phase 1.5 (Post-launch)      ← Iterate based on feedback
Phase 2 (Cross-device)       ← iOS/Watch — separate decision after Year 1 data
```

### 6.2 Phase 1.0 — MVP (must-have for launch)

| ID | Feature | Notes |
|---|---|---|
| F-1.0.01 | Menu bar icon (active/inactive states) | SF Symbol `cup.and.saucer` / `.fill` |
| F-1.0.02 | Click menu bar → window opens with toggle | `MenuBarExtra(style: .window)` |
| F-1.0.03 | Toggle switch for instant on/off | Bound to `AwakeManager.toggle()` |
| F-1.0.04 | Duration presets (5m, 15m, 30m, 1h, 2h, 5h, indefinite) | `AwakeDuration.presets` |
| F-1.0.05 | Display countdown when timer active | "Until 14:32" in menu bar header |
| F-1.0.06 | Allow-display-sleep mode | `kIOPMAssertionTypeNoIdleSleep` instead of `NoDisplaySleep` |
| F-1.0.07 | Settings window (3 tabs: General / Triggers / About) | Standard `Settings { ... }` scene |
| F-1.0.08 | Launch at Login | `ServiceManagement.SMAppService.mainApp` |
| F-1.0.09 | Activate on Launch (optional) | UserDefaults flag |
| F-1.0.10 | Quit menu item | `NSApplication.shared.terminate` |
| F-1.0.11 | AppIntents: Toggle / Start (with minutes param) / Stop | Surfaced via `AppShortcutsProvider` |
| F-1.0.12 | First-run onboarding (1 screen, optional) | Brief; max 3 sentences |

### 6.3 Phase 1.A — Automation (differentiation)

| ID | Feature | Notes |
|---|---|---|
| F-1.A.01 | **Calendar trigger** — auto-on during in-progress events | EventKit; configurable: which calendars to watch |
| F-1.A.02 | Per-event opt-out — "skip this event" toggle | Optional polish; defer if tight |
| F-1.A.03 | App-presence trigger (Zoom, Teams, Meet, Discord, Webex) | NSWorkspace running apps; bundle ID match |
| F-1.A.04 | Wi-Fi trigger — specific SSIDs | `CWWiFiClient`; entitlement `network.client` |
| F-1.A.05 | Focus mode trigger — when work Focus is active | App Intents `currentFocus` (macOS 13+) |
| F-1.A.06 | Trigger combination logic — any-OR-all (default: any) | Defined in `03-state-machine.md` |
| F-1.A.07 | Trigger management UI in Settings → Triggers | Per-trigger enable + config |
| F-1.A.08 | Permission request flow per trigger | On-demand only; deferred until enable |

### 6.4 Phase 1.C — Design (polish for launch)

| ID | Feature | Notes |
|---|---|---|
| F-1.C.01 | Refined coffee-cup animation (steam particles, pulse) | Canvas + TimelineView, 60fps — **shipped S5** ([CoffeeCupView.swift](../../Sources/UI/Components/CoffeeCupView.swift)) |
| F-1.C.02 | Liquid Glass treatment on macOS 26+ | `#available(macOS 26, *)` branch — **shipped S5** ([LiquidGlassModifier.swift](../../Sources/UI/Components/LiquidGlassModifier.swift)) |
| F-1.C.03 | Vibrancy fallback on macOS 13~25 | `.background(.ultraThinMaterial)` — **shipped S5** |
| F-1.C.04 | App icon (1024×1024, all required sizes) | Hand-designed; NOT default SF Symbol — **spec written S5** ([05-icon-spec.md](05-icon-spec.md)); PNG owner-side |
| F-1.C.05 | Custom menu bar icon variants (filled / outline / clock) | User picks in Settings — **shipped S5** ([MenuBarIconStyle.swift](../../Sources/UI/MenuBar/MenuBarIconStyle.swift)) |
| F-1.C.06 | Light/Dark mode polished | Full vibrancy support — **shipped S5** (system semantic colors throughout) |
| F-1.C.07 | Settings window typography pass | `.title` / `.header` / `.subheadline` / `.body` / `.caption` hierarchy — **shipped S5** ([Theme.swift](../../Sources/UI/Theme/Theme.swift)) |

### 6.5 Phase 1.QA — Launch prep

| ID | Item | Notes |
|---|---|---|
| F-1.QA.01 | Test coverage ≥80% (unit + UI tests) | XCTest; mock `PowerAssertion` |
| F-1.QA.02 | Manual smoke test on macOS 13, 14, 15 (and 26 if available) | Local QA matrix |
| F-1.QA.03 | TestFlight beta with ≥10 testers, ≥2 weeks | Recruit via Twitter/Reddit |
| F-1.QA.04 | Privacy Policy page hosted on GitHub Pages | URL in App Store metadata |
| F-1.QA.05 | Support page (GitHub Issues or Notion) | URL in App Store metadata |
| F-1.QA.06 | App Store screenshots (5): hero, calendar trigger, settings, dark mode, in-meeting | 1280×800 (Retina 2560×1600) |
| F-1.QA.07 | App Store description in EN + KO | KR market matters; KO copy first |
| F-1.QA.08 | Notarization & App Store submission | First review usually 1~2 weeks |

### 6.6 Phase 1.5 — Post-launch backlog (best-effort, based on feedback)

- Battery-aware mode (auto-disable below configurable %)
- Custom global keyboard shortcut (e.g., ⌥⌘C) — uses `KeyboardShortcuts` SPM package
- Custom durations (user-defined presets)
- Localization expansion (JP, ES, ZH-Hans)
- iCloud-Drive-based settings backup (file in `~/Library/Mobile Documents/`)
- Per-app "skip" rules (e.g., never auto-on for Steam)

### 6.7 Phase 2 — Cross-device (gate: Year 1 net revenue ≥ ₩2,000만)

- iOS companion app (Control Center widget, Action Button)
- Apple Watch complication
- iCloud KVStore + APNs for real-time toggle from iOS
- Setapp distribution

---

## 7. Non-Functional Requirements

### 7.1 Performance

| Requirement | Target | Measurement |
|---|---|---|
| Cold launch to menu bar visible | <500 ms | Instruments / `os_signpost` |
| Menu bar window open animation | <100 ms perceived | Manual + Instruments |
| Idle CPU usage (steady state) | <0.1% | Activity Monitor over 1 hr |
| Idle RAM usage | <30 MB resident | Activity Monitor |
| Trigger response latency (event → awake) | <2 s | Manual stopwatch test |

### 7.2 Reliability

- **Crash-free session rate**: ≥99.5%
- **Power assertion leak guarantee**: assertion is **always** released on app quit, crash, or unhandled signal. Use `signal()` handler in `main` if needed.
- **Timer drift**: ≤2 s over a 5-hour session
- **Trigger correctness**: false-positive rate <5% (e.g., shouldn't activate during a 15-min "lunch" calendar event if user excluded that calendar)

### 7.3 Accessibility

- **VoiceOver**: all interactive elements have meaningful `.accessibilityLabel`
- **Keyboard navigation**: full support; menu bar window navigable via Tab + Return
- **Dynamic Type**: respects user's preferred text size
- **High contrast**: works in Increased Contrast mode
- **Color blindness**: state never communicated by color alone (icon shape changes too)

### 7.4 Privacy & Security

- **Sandbox**: enabled (App Store requirement)
- **Entitlements (minimum required)**:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.personal-information.calendars` (only after user enables calendar trigger)
  - `com.apple.security.network.client` (for `CWWiFiClient` SSID detection)
- **No telemetry / analytics SDK** in v1
- **No third-party SDKs** in v1 (reduces dependency surface)
- **Calendar data**: read-only, never written, never transmitted
- **Privacy Policy**: clearly states data never leaves device

### 7.5 Localization

- **v1 launch**: Korean (primary), English (secondary)
- **String Catalog** (`.xcstrings`) used from day 1, even if only 2 locales
- All user-facing strings externalized; no hardcoded copy in views

### 7.6 Compatibility

| OS | Tier | Notes |
|---|---|---|
| macOS 13 Ventura | **Required** | Minimum target; `MenuBarExtra` API |
| macOS 14 Sonoma | **Required** | Test for EventKit `requestFullAccessToEvents` |
| macOS 15 Sequoia | **Required** | Default test target during dev |
| macOS 26 Tahoe | **Required + enhanced** | Liquid Glass treatment unlocked |
| Apple Silicon | **Required** | All testing happens here |
| Intel Mac | **Best-effort** | Universal binary; not actively tested |

---

## 8. Constraints

### 8.1 Technical

- **Language**: Swift 6 language mode (`SWIFT_VERSION = 6.0`)
- **UI framework**: SwiftUI only (no Storyboard, no AppKit views except where necessary, e.g., `NSStatusItem` is replaced by `MenuBarExtra`)
- **Concurrency**: Swift Concurrency (`async`/`await`, `@MainActor`); Swift 6 language mode (strict concurrency is complete by default)
- **Persistence**: `UserDefaults` for v1; migration path to SwiftData planned in `04-data-model.md`
- **Dependencies**: zero third-party SPM packages in v1 (re-evaluate at Phase 1.5)
- **Build system**: XcodeGen (`project.yml` → `.xcodeproj`); Package.swift only if SPM packages added
- **CI**: GitHub Actions (private repo) running tests on macOS-14 runner

### 8.2 Platform / regulatory

- **App Store sandboxing**: forbids many APIs (`NSAppleScript`, raw IOKit notifications). Calendar/Wi-Fi/Focus all work in sandbox; verified.
- **App Store review guidelines**: utility category. Risk: rejection for "duplicates existing functionality" (Apple has rejected sleep utilities before). **Mitigation**: emphasize automation in app description; show calendar screenshot first.
- **Apple Developer Program**: $99/year recurring (correction from earlier conversation). Single license covers Latte + future apps.
- **No background entitlement needed**: app runs as `LSUIElement` (menu bar) which is always-running; no extra background permission required.

### 8.3 Resource

- **Team**: 1 developer (you)
- **Budget**: $99/yr Dev Program + ~$0 hosting (GitHub Pages free) + 1× icon design (TBD: hire or DIY)
- **Timeline**: target ship 8~10 weeks after design phase complete

---

## 9. Risks & Mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Amphetamine adds calendar trigger before Latte ships | Medium | High (USP gone) | Ship fast (≤10 weeks); lock branding; emphasize design + integration depth |
| R-02 | App Store rejects for "duplicate functionality" | Low | High (no launch) | App description emphasizes calendar/automation; first screenshot is calendar trigger |
| R-03 | Calendar permission denied by user → 80% of value lost | Medium | Medium | Graceful degradation: Wi-Fi/app triggers work without calendar; clear value prop in onboarding |
| R-04 | Power assertion bug → user's Mac drains overnight | Low | High (1★ reviews) | `signal()` handler releases assertion on crash; integration test for assertion release on quit |
| R-05 | macOS 26 Liquid Glass APIs change between betas | Medium | Low (fallback works) | Liquid Glass is `#available`-gated; macOS 13 fallback always renders |
| R-06 | Solo developer burnout | Medium | High (project death) | Phased shipping (1.0 → 1.A → 1.C); each phase independently shippable |
| R-07 | Refund rate >5% from misunderstood UX | Low | Medium | TestFlight beta ≥2 weeks; capture confusion via feedback form |
| R-08 | EventKit `requestFullAccessToEvents` rejected by macOS 13 (only macOS 14+) | High | Low (handled in code) | Code already has `#available(macOS 14, *)` branch with macOS 13 fallback |
| R-09 | Bundle ID conflict (someone else owns `com.parkbyeongjun.latte`-like) | Low | Low | `com.parkbyeongjun.*` reverse-DNS is owner-controlled; revisit per V2-20 if owner moves to a custom domain |
| R-10 | App Store name "Latte" already taken | Medium | Medium | Backup names: `Brew`, `Wakeful`, `Sippy`; verify before locking |

---

## 10. Launch Criteria (Definition of Done for v1.0)

App ships to App Store when **all** of the following are true:

### 10.1 Functional
- [ ] All Phase 1.0 features (F-1.0.01 ~ F-1.0.12) implemented and tested
- [ ] All Phase 1.A features (F-1.A.01 ~ F-1.A.08) implemented and tested
- [ ] All Phase 1.C features (F-1.C.01 ~ F-1.C.07) implemented
- [ ] Zero P0 (crash, data loss) bugs
- [ ] Zero P1 (broken core flow) bugs
- [ ] ≤3 P2 (minor UX) bugs documented in known-issues

### 10.2 Quality
- [ ] Test coverage ≥80% on `Sources/` (excluding pure-UI views)
- [ ] All tests passing on macOS 14 + macOS 15 CI
- [ ] Manual smoke test passed on 3 macOS versions (13, 14, 15)
- [ ] Crash-free sessions ≥99% in TestFlight beta over ≥2 weeks
- [ ] No power-assertion leaks observed in 24-hour idle test

### 10.3 Submission
- [ ] App Store Connect record created
- [ ] Bundle ID, signing, provisioning profile finalized
- [ ] App icon (all sizes) integrated
- [ ] 5 screenshots in EN + KO
- [ ] App description, keywords, subtitle in EN + KO (≤170 char description, ≤30 char subtitle)
- [ ] Privacy Policy URL live (GitHub Pages)
- [ ] Support URL live
- [ ] Privacy nutrition label completed (data collected: NONE)
- [ ] Pricing set: $2.99 USD / ₩4,400 KRW (or App Store equivalent tier)
- [ ] Release type: Manual (not automatic post-approval)

### 10.4 Marketing
- [ ] Landing page (single-page, GitHub Pages)
- [ ] ProductHunt submission drafted
- [ ] 3 launch tweets drafted
- [ ] 1 launch blog post drafted (Medium or personal blog)

---

## 11. Open Questions (status as of session 2)

| ID | Question | Resolves in | Status |
|---|---|---|---|
| OQ-01 | What's the priority order when multiple triggers are active? | [03-state-machine.md §5.1–5.2](03-state-machine.md) | ✅ **Resolved (S2)** — any-OR aggregation + 60 s cool-down |
| OQ-02 | How does manual toggle interact with active triggers? | [03-state-machine.md §5.3](03-state-machine.md) | ✅ **Resolved (S2)** — 5 min snooze on manual-OFF; manual-ON-during-trigger is no-op |
| OQ-03 | Where do trigger configs live — UserDefaults or SwiftData? | [04-data-model.md §2.1](04-data-model.md) | ✅ **Resolved (S2)** — UserDefaults for v1 |
| OQ-04 | Migration strategy from UserDefaults → SwiftData for Phase 2 | [04-data-model.md §2.2](04-data-model.md) | ✅ **Resolved (S2)** — first-launch copy, fallback during transition |
| OQ-05 | Module boundaries — `Triggers/` SPM package or folder? | [02-architecture.md §3.1, §3.3](02-architecture.md) | ✅ **Resolved (S1)** — folders for v1; SPM extraction in Phase 2 |
| OQ-06 | `AwakeManager` Combine `@Published` vs `@Observable`? | [02-architecture.md §5.2](02-architecture.md) | ✅ **Resolved (S1)** — `ObservableObject` for v1 |
| OQ-07 | Onboarding screen design and copy | 06-ui-spec.md (future) | ⚪ Deferred |
| OQ-08 | App icon visual direction — minimal mug, abstract steam, or character? | 06-ui-spec.md (future) | ⚪ Deferred |
| OQ-09 | App Store category — Utilities or Productivity? | 10-release-plan.md (future) | ⚪ Deferred |
| OQ-10 | Korean copy tone — formal (-습니다) or casual (-요)? | 11-localization.md (future) | ⚪ Deferred |

**Design phase status as of session 2**: OQ-01 ~ OQ-06 closed. Remaining items (OQ-07 ~ OQ-10) are content/marketing decisions and intentionally do **not** block code work in session 3.

---

## 12. Decisions Log

| Date | Decision | Owner |
|---|---|---|
| 2026-04-25 | App name: **Latte** (vs Brew/Wakeful/Sippy/KeepUp) | Owner |
| 2026-04-25 | Primary persona: **Hybrid PM / video-call-heavy remote worker** | Owner |
| 2026-04-25 | Pricing: **$2.99 one-time** at launch (no freemium, no subscription, no free trial period) | Owner |
| 2026-04-25 | Source code: **private** GitHub repo (revisit after Year 1) | Owner |
| 2026-04-25 | Min OS: **macOS 13 Ventura** | Architectural |
| 2026-04-25 | Phase scope: **A + C only at launch**; B (iOS) deferred to Phase 2 | Owner |
| 2026-04-25 | Distribution: **App Store only** at launch (Setapp deferred) | Owner |
| 2026-04-25 | Telemetry: **none** in v1 | Privacy stance |

---

## 13. Document Change Log

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-04-25 | Initial draft (session 1) |
| 0.2 | 2026-04-25 | Session 2: marked OQ-01 ~ OQ-04 resolved with cross-references to 03/04 docs; status flipped to Approved; sign-off checklist confirmed |
| 0.2.1 | 2026-04-25 | Session 3 close: Phase 1.0 implementation completed in `Sources/`; no PRD content changes (entry recorded for traceability) |
| 0.3   | 2026-04-26 | Session 5: Phase 1.C feature rows F-1.C.01 ~ F-1.C.07 annotated with shipped-in-S5 / spec-only status; `with-clock` variant clarified to "clock" (cup with steam waves); 05-icon-spec.md cross-referenced |

---

## 14. Sign-off Checklist

- [x] Owner has read sections 1–6 and confirms scope
- [x] Owner has read section 7 (NFRs) and accepts targets
- [x] Owner has read section 9 (risks) and accepts mitigation plans
- [x] Owner agrees with Open Questions list — nothing missing that needs answering before architecture
- [x] Decisions Log accurately reflects current understanding

Approved 2026-04-25 (session 2 close). Subsequent edits require a version bump and a note in §13.
