# Latte

A macOS menu-bar utility that keeps your Mac awake **automatically based on context** — calendar events, app activity, Wi-Fi networks, external displays, and time-of-day schedules. Solves the "Mac slept mid-Zoom-call" problem that incumbents (Amphetamine, Caffeinated) leave unaddressed.

> **Status**: v1.9 code-side ship-ready. 721/721 tests passing, 23/23 smoke scenarios PASS. App Store prep (ASC submission) is the only remaining work — see [ROADMAP.md](ROADMAP.md). Pages live at https://spespark.github.io/latte/.

## What it does

- **Calendar events** — Wakes during scheduled meetings, idles between them.
- **App-presence** — Add Zoom, Slack, Final Cut, anything. Awake while it's running.
- **Wi-Fi network** — Awake on home/office Wi-Fi, idle on coffee-shop networks (or invert the logic).
- **External display** — Awake whenever a specific monitor is connected (lid-open or clamshell).
- **Schedule** — Recurring time-of-day windows (e.g. weekday 9-6) keep the machine awake.
- **Custom recurring presets** — User-defined "Until 5 PM Mon-Fri"-style quick actions in the popover.
- **Activity log** — Per-trigger history with 24h chart, 14d heatmap, daily totals, click-to-jump filtering.
- **Awake state visualization** — Menu-bar icon visually reflects whether Latte is currently keeping your Mac awake (filled cup / cup-and-saucer / clock — your pick).
- **Custom global hotkey** — Default ⌘⇧L; rebind via Settings → General with a Spotlight-style recorder.
- **First-run onboarding** — 3-step wizard so first-time users aren't dropped into an empty Settings window.
- **Launch at Login** — Standard SMAppService toggle.

Focus-mode trigger remains deferred — Apple requires a Communication Notifications entitlement to read Focus state reliably (V2-03b in `docs/v2-backlog.md`).

## Pricing

**$2.99 one-time** on the App Store. No subscription, ever — codified as a durable PRD constraint after S8b market research.

## Tech stack

- **Swift 6** + **SwiftUI** (`MenuBarExtra(.window)` macOS 13+, builds with Xcode 26+)
- **Min OS**: macOS 13 Ventura
- **Project generation**: [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml` → `.xcodeproj`)
- **Tests**: XCTest, 607 cases covering FSM transitions, trigger lifecycle, URL parsing, settings, activity logging, key-chord handling, localization catalog coverage, language preference resolution, and integration paths
- **Languages**: 11 (en source + ko hand-reviewed + 9 machine-assisted; see [TRANSLATIONS.md](TRANSLATIONS.md))

## Internationalization

Latte ships in 11 languages: `en` (source), `ko` (hand-reviewed),
`ja` / `zh-Hans` / `zh-Hant` / `es` / `de` / `fr` / `pt-BR` / `it` / `ru`
(machine-assisted; community PRs welcome).

- Pick your language on first launch (Onboarding wizard → Language step)
  or anytime via **Settings → General → Language** (restart required).
- All 940 translation cells (86 keys × 11 languages) are populated;
  `LocalizationCatalogTests` enforces complete coverage on every build.
- See [TRANSLATIONS.md](TRANSLATIONS.md) for the contributor guide.
  If your language is on the list and something reads off, please
  open a [Translation improvement issue](.github/ISSUE_TEMPLATE/translation_improvement.md)
  or a PR — both are appreciated.

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

Latte ships with a `.smoke/` config wired to `~/dev/smoke-harness/` — a separate cross-project tool that drives the app through 22 deterministic scenarios via screencapture, defaults, pmset, and the URL scheme. End-to-end run takes ~6:14 and produces PNG artifacts plus a JSONL report.

```bash
~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte
```

See [docs/store/screenshot-guide.md](docs/store/screenshot-guide.md) for marketing screenshot capture (4/5 shots fully automated; 1/5 manual hover).

## Documents

| Document | Purpose |
|---|---|
| [ROADMAP.md](ROADMAP.md) | Multi-session execution plan + milestone gates |
| [TRANSLATIONS.md](TRANSLATIONS.md) | Contributor guide for the 11-language catalog |
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
│   ├── App/                   ← @main + composition root + URL handlers + AppEnvironment
│   ├── Core/                  ← FSM, power assertion, settings, launch-at-login, key-chord coordinator, activity log
│   ├── Triggers/              ← Calendar / App / Wi-Fi / ExternalDisplay / Schedule (Focus deferred)
│   ├── Intents/               ← AppIntents + AppShortcuts
│   └── UI/
│       ├── Components/        ← CoffeeCupView (Canvas + TimelineView), charts
│       ├── Demo/              ← latte://demo/cup window
│       ├── MenuBar/           ← popover root + duration / preset rows + key handler
│       ├── Onboarding/        ← First-run wizard
│       ├── Settings/          ← General / Triggers / Activity / About + URL routing
│       └── Theme/
├── Resources/                 ← Info.plist + Assets.xcassets
├── Configuration/             ← Latte.entitlements
├── Tests/                     ← 607 XCTest cases
├── scripts/                   ← deploy_pages.sh / validate_pages.sh
├── .smoke/                    ← smoke-harness config + 22 scenarios
└── docs/
    ├── design/
    ├── site/                  ← marketing + privacy HTML (gh-pages source of truth)
    └── store/                 ← App Store metadata
```

## Architecture (brief)

- **6-state FSM** (`AwakeStateMachine.step` is a pure function, `AwakeManager` is its `@MainActor` wrapper) — see [docs/design/03-state-machine.md](docs/design/03-state-machine.md) for the transition table.
- **Trigger-as-AsyncStream** — each trigger publishes `TriggerVote` updates to a coordinator, which OR-folds them into a single awake decision. The S8b consumer-task-keepalive fix (commit `45e73fc`) ensures cancelling a per-trigger task doesn't drop the underlying stream storage.
- **Power assertion** via `IOKit/IOPMLib`, wrapped in a protocol so unit tests use a mock instead of mutating real system state.
- **SwiftUI views are dumb** — `Settings`, `MenuBar`, `Onboarding`, `Demo` are pure projections of `AppEnvironment.shared` + per-view `ObservedObject` bindings. State changes go through `AwakeManager` or `TriggerCoordinator`.

## License

All rights reserved (App Store distribution).
