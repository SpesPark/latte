# Latte — Project Roadmap

> Multi-session execution plan for Latte (working folder: `Caffeinated-Clone/`).
>
> **Current phase**: Build green (session 6 complete); 178/178 tests passing
> **Current session**: 6 of ~10 (complete)
> **Next session entry point**: see [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) — Session 7 = Test coverage + QA

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
| 7 | **Test coverage + QA** | ≥80% coverage, manual smoke test on macOS 13/14/15 | Test files, QA log | 🟡 Next |
| 8 | **App Store prep** *(needs Dev Program + icon)* | Metadata, screenshots, Privacy Policy, submission | App Store Connect record, GitHub Pages site | 🔴 Blocked: Dev Program, Icon |
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
