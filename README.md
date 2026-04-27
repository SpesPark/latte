# Latte

A macOS menu-bar utility that keeps your Mac awake **automatically based on context** — calendar events, app activity, Wi-Fi networks. Solves the "Mac slept mid-Zoom-call" problem that incumbents (Amphetamine, Caffeinated) leave unaddressed.

> **Status**: v1.0 code-side ship-ready. 309/309 tests passing. Owner-side App Store prep is the only remaining work — see [ROADMAP.md](ROADMAP.md).

## What it does

- **Calendar events** — Wakes during scheduled meetings, idles between them.
- **App-presence** — Add Zoom, Slack, Final Cut, anything. Awake while it's running.
- **Wi-Fi network** — Awake on home/office Wi-Fi, idle on coffee-shop networks (or invert the logic).
- **Awake state visualization** — Menu-bar icon visually reflects whether Latte is currently keeping your Mac awake (filled cup vs cup-and-saucer vs clock — your pick).
- **First-run onboarding** — 3-step wizard so first-time users aren't dropped into an empty Settings window.
- **Launch at Login** — Standard SMAppService toggle.

Focus mode trigger is deferred to v1.x — Apple requires a Communication Notifications entitlement to read Focus state reliably (V2-03b in `docs/v2-backlog.md`).

## Pricing

**$2.99 one-time** on the App Store. No subscription, ever — codified as a durable PRD constraint after S8b market research.

## Tech stack

- **Swift 5.10** + **SwiftUI** (`MenuBarExtra` macOS 13+)
- **Min OS**: macOS 13 Ventura
- **Project generation**: [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml` → `.xcodeproj`)
- **Tests**: XCTest, 309 cases covering FSM transitions, trigger lifecycle, URL parsing, settings, and integration paths

## URL scheme

Latte registers `latte://` for internal deep linking. Used by the smoke-harness for marketing capture; also useful as a first step toward Shortcuts/AppIntents-based quick actions in v1.x.

```
latte://settings              # opens Settings (General tab default)
latte://settings/general
latte://settings/triggers
latte://settings/about
latte://demo/cup              # demo cup window for capture
latte://demo/cup?fill=0.55&accent=caramel&awake=true
```

`LSMultipleInstancesProhibited = true` so URL deliveries forward to the existing instance instead of spawning a duplicate.

## Setup

```bash
brew install xcodegen
xcode-select --install   # if Xcode CLT not present

xcodegen generate
open Latte.xcodeproj
```

Then in Xcode → `Latte` target → Signing & Capabilities → set your Team and Bundle ID.

## Build & test from CLI

```bash
xcodegen generate
xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64"
xcodebuild -scheme Latte -configuration Release \
           -destination "platform=macOS,arch=arm64" build
```

## Smoke harness

Latte ships with a `.smoke/` config wired to `~/dev/smoke-harness/` — a separate cross-project tool that drives the app through 12 deterministic scenarios via screencapture, defaults, pmset, and the URL scheme. End-to-end run takes ~2:30 and produces 17 PNG artifacts.

```bash
~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte
```

See [docs/store/screenshot-guide.md](docs/store/screenshot-guide.md) for marketing screenshot capture (4/5 shots fully automated; 1/5 manual hover).

## Documents

| Document | Purpose |
|---|---|
| [ROADMAP.md](ROADMAP.md) | Multi-session execution plan + milestone gates |
| [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) | Where to pick up next session |
| [docs/design/01-PRD.md](docs/design/01-PRD.md) | Product requirements, target user, KPIs, scope, risks |
| [docs/design/02-architecture.md](docs/design/02-architecture.md) | Module structure, concurrency, contracts, dependency policy |
| [docs/design/03-state-machine.md](docs/design/03-state-machine.md) | 6-state FSM + transition table |
| [docs/design/04-data-model.md](docs/design/04-data-model.md) | Persistence schema + migration plan |
| [docs/design/05-icon-spec.md](docs/design/05-icon-spec.md) | App icon design brief |
| [docs/v2-backlog.md](docs/v2-backlog.md) | Items deferred from v1.0 |
| [docs/store/](docs/store/) | App Store metadata + screenshot guide |
| [docs/site/](docs/site/) | Marketing landing + privacy policy (gh-pages source of truth) |

## Directory layout

```
Latte/
├── README.md                  ← you are here
├── ROADMAP.md
├── project.yml                ← XcodeGen spec
├── Sources/
│   ├── App/                   ← @main + composition root + URL handler
│   ├── Core/                  ← FSM, power assertion, settings, launch-at-login
│   ├── Triggers/              ← Calendar / App / Wi-Fi (Focus deferred)
│   ├── Intents/               ← AppIntents + AppShortcuts
│   └── UI/
│       ├── Components/        ← CoffeeCupView (Canvas + TimelineView)
│       ├── Demo/              ← latte://demo/cup window
│       ├── MenuBar/
│       ├── Onboarding/        ← First-run wizard
│       ├── Settings/          ← General / Triggers / About + URL routing
│       └── Theme/
├── Resources/                 ← Info.plist + Assets.xcassets
├── Configuration/             ← Latte.entitlements
├── Tests/                     ← 309 XCTest cases
├── .smoke/                    ← smoke-harness config + scenarios
└── docs/
    ├── design/
    ├── site/                  ← marketing + privacy HTML
    └── store/                 ← App Store metadata
```

## Architecture (brief)

- **6-state FSM** (`AwakeStateMachine.step` is a pure function, `AwakeManager` is its `@MainActor` wrapper) — see [docs/design/03-state-machine.md](docs/design/03-state-machine.md) for the transition table.
- **Trigger-as-AsyncStream** — each trigger publishes `TriggerVote` updates to a coordinator, which OR-folds them into a single awake decision. The S8b consumer-task-keepalive fix (commit `45e73fc`) ensures cancelling a per-trigger task doesn't drop the underlying stream storage.
- **Power assertion** via `IOKit/IOPMLib`, wrapped in a protocol so unit tests use a mock instead of mutating real system state.
- **SwiftUI views are dumb** — `Settings`, `MenuBar`, `Onboarding`, `Demo` are pure projections of `AppEnvironment.shared` + per-view `ObservedObject` bindings. State changes go through `AwakeManager` or `TriggerCoordinator`.

## License

All rights reserved (App Store distribution).
