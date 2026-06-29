# Rebrand checklist — 상호 확정 → bundle-ID rewire → publish

> Prepared in S52 so the moment the owner picks the 상호, the rewire is a
> ~5-minute scripted pass instead of a grep-sweep session.
> Tool: [`scripts/rebrand.sh`](../scripts/rebrand.sh) (dry-run by default).

## Why this exists

- The account is **Individual** → the App Store seller field shows the personal
  legal name. The owner wants a brand → Org account (개인사업자 + D-U-N-S under
  the 상호) later via **App Transfer**.
- **Bundle ID is permanent after first publish** → it must be brand-aligned
  (`com.<brand>.latte`) *before* the v1.0 submission.
- **App Transfer is blocked for apps using iCloud** → the Individual→Org
  transfer must happen during v1.x, **before** iCloud Phase-2 activation.

## How to run

```bash
scripts/rebrand.sh com.<brand>              # dry-run: per-file occurrence preview
scripts/rebrand.sh com.<brand> --apply      # rewire + auto --check + manual checklist
scripts/rebrand.sh --check                  # post-apply guard: fails if the old
                                            # prefix survives outside history docs
```

The script derives `com.<brand>.latte`, `com.<brand>.latte.tests`, and
`iCloud.com.<brand>.latte` from the prefix — pass the prefix only.

## Inventory (as of S52, 16 functional + 7 living-doc files)

Discovery command (re-run if this table smells stale):
`grep -rln "com.parkbyeongjun" . --exclude-dir=.git`

| Category | File | What |
|---|---|---|
| build | `project.yml` | `bundleIdPrefix` + app/tests `PRODUCT_BUNDLE_IDENTIFIER` |
| signing | `Configuration/Latte.icloud.entitlements` | iCloud container ID (+ comment) — **dark** until Phase 2 |
| source | `Sources/Core/Logging.swift` | `LatteLog.subsystem` |
| source | `Sources/Core/{LanguagePreference,LaunchAtLoginManager,PowerAssertion,SettingsStore}.swift`, `Sources/UI/Onboarding/OnboardingState.swift` | per-file `Logger(subsystem:)` literals |
| source | `Sources/Core/CloudKitSyncEngine.swift` | `defaultContainerIdentifier` |
| tests | `Tests/LanguagePreferenceTests.swift` | UserDefaults suite name |
| smoke | `.smoke/config.yml`, `.smoke/scenarios/{04-launch-at-login,05-calendar-picker}.sh` | `bundle_id` + `tell application id` |
| store tooling | `docs/store/screenshot-guide.md`, `docs/store/screenshots/_scripts/capture.sh` | defaults domain (`BID`) |
| published page | `docs/site/privacy.html` | container/plist paths shown to users → **redeploy gh-pages after** |
| contributor | `.github/ISSUE_TEMPLATE/bug_report.md` | log-stream subsystem filter |
| living docs | `docs/design/{01-PRD,02-architecture,04-data-model,07-shortcut-recorder,09-c3-activity-history,10-c3-icloud-sync-rfc}.md`, `docs/v2-backlog.md` | references in current-truth design docs |

**Never rewritten (history allowlist):** `ROADMAP.md`, `docs/SESSION_HANDOFF.md`,
`docs/QA_LOG.md` — session records keep the old prefix as audit trail; `--check`
ignores them.

**Confirmed NOT affected:** `Configuration/Latte.entitlements` (no literal),
`Resources/Info.plist` copyright (neutral "Copyright © 2026"), store copy in
`docs/store/*.{md,txt}` (no name/prefix), screenshots (no visible bundle ID).

## Post-apply manual steps (owner side)

1. `xcodegen generate` → signed build → `codesign -d --entitlements -` verify.
2. `scripts/run_tests.sh` — full suite must stay green (suite names rewired too).
3. ⚠ **TCC grants reset with a new bundle ID.** Re-grant on the owner machine:
   Calendar + Location (Wi-Fi trigger) for the app; Screen Recording +
   Accessibility for the screenshot pipeline. Then re-run smoke + `capture.sh`.
4. Owner defaults migration (new domain starts empty):
   `defaults export com.parkbyeongjun.latte /tmp/latte.plist && defaults import com.<brand>.latte /tmp/latte.plist`.
   Sandbox container moves to `~/Library/Containers/com.<brand>.latte/`
   (activity-log.json etc. start fresh — copy from the old container if wanted).
5. Redeploy gh-pages `privacy.html` (source already rewired in `docs/site/`).
6. ASC: register the new App ID (`com.<brand>.latte`). The iCloud container
   (`iCloud.com.<brand>.latte`) is registered only at Phase-2 activation.
7. Optional: `NSHumanReadableCopyright` → `© 2026 <brand>` (currently neutral).

## Optional pre-step (code, needs owner OK — not done in S52)

Five Swift files hardcode the `Logger(subsystem:)` literal instead of using
`LatteLog.subsystem` (Logging.swift). Routing them through the constant would
shrink the source rewire surface from 7 files to 1. Pure refactor, but it is
binary churn during the App Store push — deliberately left to an owner call.
