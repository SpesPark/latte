# Latte — Project Roadmap

> Multi-session execution plan for Latte (working folder: `Caffeinated-Clone/`).
>
> **Current phase**: Design (Tier 1 docs)
> **Current session**: 1 of ~10
> **Next session entry point**: see [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)

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
| 1 | **Foundation: PRD + Architecture** | Lock product scope, lock module/layer structure | `01-PRD.md`, `02-architecture.md`, `ROADMAP.md`, `SESSION_HANDOFF.md` | 🟡 In progress |
| 2 | **Design close-out** | Resolve all Open Questions before code | `03-state-machine.md`, `04-data-model.md` | ⚪ Pending |
| 3 | **Phase 1.0 implementation** | Rewrite Sources to match architecture; implement MVP features | All `Sources/**/*.swift`, replaces current skeleton | ⚪ Pending |
| 4 | **Phase 1.A — Triggers** | Calendar + App + Wi-Fi + Focus triggers fully implemented | `Sources/Triggers/*.swift`, integration tests | ⚪ Pending |
| 5 | **Phase 1.C — Design polish** | Coffee cup animation, Liquid Glass + fallback, app icon spec | UI files, asset catalog updates | ⚪ Pending |
| 6 | **Build verification** *(needs Xcode installed)* | First successful build, fix compile errors, run tests | Working `.app` bundle, all tests passing | 🔴 Blocked: Xcode |
| 7 | **Test coverage + QA** | ≥80% coverage, manual smoke test on macOS 13/14/15 | Test files, QA log | ⚪ Pending |
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
