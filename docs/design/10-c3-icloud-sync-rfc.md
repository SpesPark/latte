# 10 — iCloud Sync RFC (C-3 history + B1.2 chord + Settings), joint design

| | |
|---|---|
| **Document version** | 0.3 (S49, 2026-05-27) — design only; §12 owner decisions recorded (S38). **S49: H1 fix** — §3 migration bullet de-contradicted vs §11 (absent `schemaVersion` → `1`, not fresh; the total-settings-loss trap), matching the corrected 04-data-model §2.2/§4.1/§6.2 |
| **Status** | **Decisions locked 2026-05-18** (Q1=B-2, Q2=approved, Q5=v2.0[P1+2]/v2.1[P3] — see §12). Phase 1 (dark, no behaviour change) is now implementable. Phase ≥ 2 still blocks on S8.5. |
| **Supersedes** | nothing; **extends** [04-data-model.md](04-data-model.md) §2 (OQ-04), [09-c3-activity-history.md](09-c3-activity-history.md) §6/§7/§14, [07-shortcut-recorder.md](07-shortcut-recorder.md) §1 |
| **Resolves** | the "iCloud sync — joint design with B1.2, schema-integration risk if shipped solo" deferral recorded in 09-c3 §14 and 07-spec §1 |

> This is the **RFC-first / architecture-only** pass the SESSION_HANDOFF recommended
> before opening an implementation worktree. It deliberately makes **zero code
> changes** — the deliverable is a reviewed, internally-consistent design whose
> purpose is to make the *future* implementation session's verification
> low-risk. **§12 Q1/Q2/Q5 were answered by the owner 2026-05-18 (S38)** —
> Phase 1 (the dark, zero-behaviour-change seam) is now an actionable
> autonomous session; Phase ≥ 2 remains S8.5-gated.

---

## §1. Why one RFC for three things

Three separately-deferred items all block on the same decision:

1. **C-3 activity-log iCloud sync** — deferred in 09-c3 §10/§14.
2. **B1.2 keyboard-chord iCloud sync** — deferred in 07-spec §1.
3. **Settings → SwiftData + CloudKit migration** — the long-planned OQ-04 event
   in 04-data-model §2.2.

09-c3 §14 states the reason explicitly: *"postponed for joint design with B1.2
iCloud-chord-sync — both touch the same Settings schema and a solo ship would
risk migration churn."* That risk is concrete: 04-data-model §2.2 commits the
project to a **one-time UserDefaults → SwiftData migration at first launch of
v2.0**. That migration is a once-per-app-lifetime event. If the chord ships its
own mini-CloudKit path first, we either (a) migrate just the chord now and
re-migrate everything at v2.0 (double churn, two fallback windows, two
schemaVersion bumps), or (b) trigger the full SwiftData migration early for one
setting. Both are worse than doing it once, deliberately, for everything.

**Therefore the core recommendation of this RFC is: do not ship any sync
piecemeal. The single CloudKit enablement *is* the OQ-04 v2.0 migration event,
and it covers Settings (including the chord) and — separately — the activity
log.**

> **Not a contradiction of the non-goals list.** v2-backlog "Won't-do" line
> *"iCloud sync of trigger settings — out of v1 scope … **Re-evaluate
> post-v1.0 ship**"* is a re-evaluation *gate*, not a hard no. This RFC **is**
> that re-evaluation, opened post-v1.9. PRD §7.4's *"No telemetry / analytics
> SDK"* non-goal is **permanent and untouched** — §5 shows sync to the user's
> own private DB introduces no developer-side data collection, so the
> "No Data Collected" / local-first stance (PRD §7.4) is *preserved*, not
> traded away.

---

## §2. The three sync surfaces and their *current* storage

| Surface | Storage today | Owner of encoding | Conflict-safe model |
|---|---|---|---|
| **Settings** (all trigger configs, general prefs, **B1.2 `shortcutChord`**, retention, chart colours, whitelist, recurring presets…) | `UserDefaults.standard` via `SettingsStore` protocol ([02-architecture](02-architecture.md) §4.3, [04-data-model](04-data-model.md) §3) | per-caller `Codable` → JSON `String`/`Data` | last-writer-wins per key (04-data-model §2.2 accepts this) |
| **Activity log** | own JSON file `~/Library/Application Support/Latte/activity-log.json` + `ActivityLogStore` actor, 14-day ring buffer; **decoupled from `SettingsStore`** (09-c3 §3/§7) | `ActivityLogStore` (top-level `version: Int` wrapper, 09-c3 §7) | **append-only event log — LWW is wrong** (see §6) |
| **B1.2 chord** | a *subset* of Settings: `SettingsKey.shortcutChord` (JSON `String`), plus `keyboardShortcutEnabled` Bool | `KeyChord` Codable (07-spec §2) | rides Settings, but needs **per-device override** (see §7) |

The critical structural fact: **the activity log is not in `SettingsStore`** and
must not be folded into it. It has a fundamentally different data shape
(append-only events vs. last-writer-wins key/value) and a stricter privacy
contract (09-c3 §6). The "same Settings schema" risk in 09-c3 §14 is about the
*migration mechanism* (one OQ-04 event), **not** about co-locating the two
datasets. They sync as **two domains with two storage models and two conflict
policies**, enabled by **one** entitlement/migration event.

---

## §3. Domain A — Settings sync (SwiftData + CloudKit private DB)

Adopt 04-data-model §2.2 as written. No new invention here; this RFC only pins
the parts it left open.

- **Store**: SwiftData model container; iCloud via
  `ModelConfiguration(cloudKitDatabase: .private(<container-id>))`. Private
  database only — never public, never shared (privacy, §5).
- **Migration**: follow 04-data-model §2.2, with the **absent-`schemaVersion`
  correction now folded into that doc**: step 1 must treat an *absent*
  `schemaVersion` as `1`, **not** as a fresh install. The shipped v1.x app never
  wrote the key, so an "absent → fresh → skip" reading would skip migrating
  every real upgrading user — a silent total-settings-loss trap. The pre-built
  `SettingsMigration.currentSchemaVersion` already defaults absent → `1` (§11),
  and §2.2 / §4.1 / §6.2 were corrected to match. Otherwise per §2.2: copy every
  *present* `SettingsKey` into a typed SwiftData entity, write `schemaVersion = 2`,
  set `migrationCompleted = true` in UserDefaults, keep UserDefaults as read-only
  fallback for **one minor version** then remove. (On a genuinely fresh v2.0
  install the copy finds no present keys — a harmless no-op.)
- **Conflict**: per-record last-writer-wins (04-data-model §2.2). Acceptable:
  settings are low-frequency, single-user, and a clobbered toggle is recoverable
  by re-toggling. **Exception: the chord — see §7.**
- **Schema-version interaction**: the shipped key set is now well beyond the v1
  enum frozen in 04-data-model §5 (it omits `keyboardShortcutEnabled`,
  `shortcutChord`, `externalDisplayWhitelist`, `activityRetentionDays`,
  `activityChartColors`, `recurringQuickPresets`, `didSeedBuiltinPresets`, …).
  The migration must enumerate **`SettingsKey.allCases` at v2.0 build time**, not
  any hand-maintained doc list. (Doc note: 04-data-model §5's enum snapshot was
  refreshed in S38 and now carries an explicit "`allCases` is authoritative, not
  this snapshot" pointer, so the migration stays correct regardless — the
  staleness this RFC flagged at S37 is resolved. See §13.)

---

## §4. Domain B — Activity-log sync

Two viable options. This RFC **recommends Option B-2** and treats B-1 as the
explicit fallback if the owner wants the smallest possible v2.0.

### B-1 — Keep activity log device-local (defer cross-device history)

- Activity log stays exactly as shipped: local JSON + actor, never leaves the
  device.
- Cross-device history becomes a documented **non-goal**, not a deferral.
- **Pro**: zero privacy surface change, zero new merge code, zero CloudKit cost
  for the log, ship v2.0 faster.
- **Con**: a user with two Macs sees two disjoint histories. Given C-3 is a
  *personal observability* feature (not collaborative), this is tolerable.

### B-2 — CloudKit custom zone, append-only union merge (recommended)

- Each `ActivityLogEntry` becomes one `CKRecord` in a **private-database custom
  zone** (`activity-log` zone), record name = a **content-addressed id**:
  `"<deviceUUID>-<monotonicSeq>"` (or SHA-256 of the immutable tuple). Entries
  are immutable once written.
- Sync = **union** of all devices' records, then the existing 14-day GC runs
  locally on the merged set. **Never last-writer-wins** — LWW on an append-only
  log silently destroys history when two devices are awake the same day.
- Idempotent: re-uploading an existing record name is a no-op; merge is
  commutative and associative, so device wake order doesn't matter.
- The on-disk JSON file stays as the **local cache / offline buffer**; CloudKit
  is the durable union. Offline writes queue and flush on reconnect.
- **Pro**: correct multi-device history; reuses the existing ring-buffer GC
  unchanged; the immutable-entry model makes merge trivial and test-pure.
- **Con**: new merge + zone code (but pure and unit-testable — §10); CloudKit
  quota (negligible: ~1 small record per trigger fire, 14-day GC bounds it).

**Recommendation: B-2.** The append-only immutable-entry shape that C-3 already
ships (09-c3 §2) makes union-merge nearly free and is the *reason* the original
design chose structured entries over mutable state. B-1 remains a one-paragraph
fallback if owner wants minimal v2.0 scope.

---

## §5. Privacy contract — the load-bearing section

09-c3 §6 commits Latte to the App Store **"No Data Collected"** label. Syncing
must not break it. Analysis:

1. **CloudKit *private* database is the user's own iCloud, not Latte's server.**
   Apple's App Store privacy guidance: data the developer *cannot access* —
   stored in the user's private CloudKit DB — is generally **not "collection by
   the developer."** Latte never sees it; there is no Latte-side server, account,
   or analytics. **"No Data Collected" can be preserved** *iff* all four hold:
   - **Private database only.** Never `.public`, never `.shared`. (Hard rule.)
   - **No developer-side processing.** No CloudKit server-to-server export, no
     analytics, no telemetry on synced data. (Consistent with PRD §7.4
     "no telemetry" non-goal, v2-backlog "Won't-do".)
   - **The activity-log structured-reasonCode discipline carries over
     unchanged.** 09-c3 §6's exclusions (no SSID, app name, calendar title,
     Focus name, schedule label, display vendor) become *more* important once
     entries leave the single device — but the design already persists only
     `triggerId + timestamp + ON/OFF + reasonCode`, so **no new redaction work
     is needed**. The privacy boundary was drawn at the right place in S14.
   - **Chord/settings carry no PII.** A modifier mask + key code, trigger
     enable flags, SSIDs… wait: **Wi-Fi SSIDs and app bundle IDs *are* in
     Settings** (`wifiTriggerSSIDs`, `appTriggerBundleIDs`). These are *user
     configuration*, not *collected behavioural data*, and they go only to the
     user's own private DB — still within "No Data Collected" by the same
     reasoning as Apple's own Keychain/iCloud-backed settings. **But this must
     be stated explicitly in the App Store privacy questionnaire rationale and
     re-confirmed at submission.** Flag for §12.
2. **App Store review justification (prepare ahead).** Reviewer may ask "why
   does a caffeine utility need iCloud?" Answer: *"Latte syncs the user's own
   trigger configuration and personal awake-history across the user's own Macs
   via their private iCloud database. No data is sent to the developer; the app
   has no server."* Mirror the V2-03b entitlement-justification playbook.
3. **Privacy doc surfaces to update at ship** (NOT now): `docs/site/privacy.html`
   gains an "iCloud sync (your private database only)" paragraph;
   App Store Connect privacy answers re-reviewed. Tracked, not done here.

---

## §6. Conflict resolution — two policies, never one

| Domain | Policy | Why |
|---|---|---|
| Settings (Domain A) | per-record **last-writer-wins** | low-frequency single-user edits; clobber is re-toggle-recoverable; matches 04-data-model §2.2 |
| Activity log (Domain B) | **append-only union merge**, immutable entries, local 14-day GC on merged set | LWW on an event log destroys concurrent-day history — categorically wrong |
| B1.2 chord | LWW on the *value*, **per-device registration best-effort**, optional non-synced local override | a chord valid on Mac A may be reserved on Mac B — see §7 |

The single most important invariant: **the activity log must never go through a
last-writer-wins path.** Any implementation that funnels both domains through
one generic "sync the blob" mechanism is a latent data-loss bug. The
two-domain split in §2 exists to make this structurally impossible.

---

## §7. B1.2 chord co-design

The chord is a Settings key, so it rides Domain A's LWW sync **for its value**.
But registration is device-physical:

- On sync-in of a new chord value, the receiving device attempts
  `HotKeyRegistrar.register(chord:)` (existing 07-spec §2 API).
- **If registration fails** (chord reserved by another app on *this* Mac):
  keep the synced *value* (do not clobber the user's intent) and surface the
  **already-shipped disabled-state UX cue** (07-spec polish "J", shipped S17 —
  opacity + "Enable above to record" hint pattern). Do **not** silently drop or
  rewrite the synced value. The mismatch is visible, not corrupt.
- **Optional per-device override**: a *non-synced* `shortcutChordDeviceOverride`
  (new local-only key, deliberately excluded from the SwiftData/CloudKit model).
  If set, it wins locally and never propagates. This is the standard
  "synced default + local override" pattern and resolves the
  Mac-A-vs-Mac-B-reservation collision without per-device sync complexity.
- 07-spec §1's other two deferrals (per-action chords, reserved-by-other-app
  indicator) stay **out of scope** — unchanged by this RFC.

---

## §8. Migration & rollout

- **One event.** Phase 2 (§11) performs the 04-data-model §2.2 migration once,
  for everything in `SettingsKey.allCases`. `schemaVersion` 1 → 2.
- **Fallback window.** UserDefaults retained read-only through v2.0, then
  deleted in **v2.1** — exactly the 04-data-model §2.2 "Why not delete
  UserDefaults immediately after migration?" rationale (re-runnable if
  migration partially failed; removed after one minor release of stable
  observation).
- **Kill-switch.** A build-time/remote-absent flag that disables CloudKit and
  falls back to local SwiftData (sync off, app fully functional). Mirrors the
  project's established "ships dark, flip on when verified" discipline
  (cf. Activate-at-launch gating, FocusTrigger comment-out). No remote config
  service exists or is wanted (PRD §7.4) — so this is a compile-time
  `LATTE_ICLOUD_SYNC` gate plus graceful degradation when the iCloud account is
  signed out / container unavailable (treat as "sync off", never block the app).
- **Activity-log migration** (if B-2): existing local JSON entries are uploaded
  to the custom zone on first run with content-addressed ids → idempotent, no
  duplication, no history loss. The 09-c3 §7 `version: Int` wrapper already
  gives the version seam.

---

## §9. Entitlements & Apple gates

- **Blocks on S8.5** (Apple Developer Program). CloudKit needs the paid program
  + an iCloud container provisioned on the App ID +
  `com.apple.developer.icloud-services` / `com.apple.developer.icloud-container-identifiers`
  in `Configuration/Latte.entitlements`. Same dependency shape as V2-03b.
- **Container id**: propose `iCloud.com.parkbyeongjun.latte` (tracks the bundle
  id; revisit if V2-20 changes the bundle prefix — note the coupling).
- **Cannot be smoke-tested by the existing harness** (no Apple Dev entitlement
  in adhoc builds; same permanent limitation noted for V2-30 owner-only items).
  Verification strategy is protocol-seam unit tests (§10) + owner manual
  multi-device smoke once entitled.

---

## §10. Test strategy (consistent with the codebase's protocol-injection pattern)

The codebase already standardises on protocol seam + mock for every external
dependency: `SettingsStore`/`UserDefaultsSettingsStore`,
`HotKeyRegistrar`/`MockHotKeyRegistrar`, `DisplaySource`/`MockDisplaySource`,
`PowerSource`. CloudKit follows the **same** pattern — no exceptions.

- **New seam**: `CloudSyncEngine` protocol + `MockCloudSyncEngine`. **No
  `CKContainer` / `CKDatabase` call anywhere outside the single production
  adapter** (mirror the 04-data-model §2.2 lint rule:
  `grep -r "CKContainer\|CKDatabase" Sources/ | grep -v CloudKitSyncEngine.swift`
  → zero matches).
- **Pure, CloudKit-free unit tests** for the parts that carry the risk:
  - Domain B **union-merge is a pure function** over `[ActivityLogEntry]` →
    test commutativity, associativity, idempotency, GC-after-merge, and the
    content-addressed-id collision-freeness. No CloudKit needed.
  - Domain A LWW resolution is a pure function over `(local, remote, timestamps)`.
  - Chord sync-in: inject a `MockHotKeyRegistrar` that fails `register(chord:)`
    → assert value retained + disabled-cue path + override precedence.
  - Migration: reuse the existing `schemaVersion` fixture approach
    (04-data-model migration tests) — seed UserDefaults v1, run migration,
    assert SwiftData parity for **all** `SettingsKey.allCases`.
- **Conflict simulation**: `MockCloudSyncEngine` scripts "device B wrote X at
  t1, device A wrote Y at t2" sequences deterministically; no real iCloud.
- **Owner manual smoke** (post-entitlement, two real Macs): the only thing the
  unit suite cannot cover — add as a handoff manual-smoke step, not an
  automated harness scenario (consistent with the V2-30 owner-only boundary).

Net: the regression-bearing logic (merge, LWW, migration, chord fallback) is
**100% pure-unit-testable without CloudKit**. The only owner-gated part is the
final real-device confirmation. This is exactly the "minimise verification
error" property the RFC-first approach is meant to buy.

---

## §11. Phasing (each phase independently shippable & verifiable)

| Phase | Scope | Verifiable by | Owner/Apple gate |
|---|---|---|---|
| **0** | This RFC + owner answers §12 | internal-consistency review | ✅ **DONE 2026-05-18** (Q1=B-2, Q2=approved, Q5=v2.0[P1+2]/v2.1[P3]) |
| **1** | `CloudSyncEngine` protocol seam + `MockCloudSyncEngine` + entitlement plumbing + `cloudKitDatabase` wiring **behind the compile-time kill-switch (ships dark, no behaviour change)** | full unit suite green; app behaviour identical with sync off | S8.5 (entitlement file only; can stub container until then) |
| **2** | Domain A: OQ-04 migration for all `SettingsKey.allCases` + LWW resolver + chord value sync. **Pure logic pre-built dark in S42** (see note); the SwiftData `@Model` write (forces macOS 14) + live CloudKit are the gated activation. | pure migration/LWW/chord unit tests; manual single-device upgrade smoke | S8.5 live + macOS-14 target bump for the `@Model` write |
| **3** | Domain B: activity-log custom-zone union merge **(or adopt B-1 and close as non-goal)**. **Pure merge logic pre-built dark in S43** (see note); the CloudKit custom-zone wiring is the gated activation. | pure merge unit tests (commutativity/associativity/idempotency/GC/content-addressed-id) — green | S8.5 live (CloudKit zone wiring only) |
| **4** | Chord per-device override polish + privacy-doc + App Store privacy re-answer | unit + owner two-Mac manual smoke | S8.5 + S9 metadata |

Phases 2 and 3 are **independent** (different domains, different storage) and
could be reordered or parallelised. Phase 1 is a hard prerequisite for both and
is the cheapest to verify (it changes nothing observable).

> **Phase 1 landed dark in S41 (2026-05-24).** Shipped: the `CloudSyncEngine`
> seam + `MockCloudSyncEngine`; the `LATTE_ICLOUD_SYNC` compile-time kill-switch
> (off by default); `AppEnvironment` injection + a `startCloudSyncIfNeeded()`
> boot hook; the `#if LATTE_ICLOUD_SYNC` `CloudKitSyncEngine` skeleton
> (account-availability gate only) with the §10 CloudKit-isolation lint guard in
> `check_doc_drift.sh`; and a staged-**inactive** `Configuration/Latte.icloud.entitlements`.
> The default build is CloudKit-free and behaviour-identical (626 tests green); a
> flag-on build compiles the adapter clean under Swift 6. Phase 2 (S8.5-gated)
> flips the switch, activates the entitlement, and attaches the Domain A/B drivers.

> **Phase 2 pure logic pre-built dark in S42 (2026-05-24).** Owner-confirmed the
> CloudKit-free pre-build (the only autonomous path at the S41 boundary). Shipped
> as pure value types in `Sources/Core`, fully unit-tested without iCloud:
> - **`SettingsLWWResolver`** (Domain A only) — per-record last-writer-wins;
>   strictly-later remote wins, exact tie keeps local (§3/§6). The activity log
>   never reaches it (§6 invariant). 10 tests.
> - **`SettingsMigration`** — `snapshot(from:now:)` enumerates every present
>   `SettingsKey` (compiler-enforced exhaustive `SettingsKey.valueType`, 34 cases)
>   into a Codable `SettingsSnapshot` stamped `schemaVersion = 2`; absent keys
>   stay absent. Modelled as **plain Codable, not a SwiftData `@Model`**, so it
>   stays on the **macOS 13** deployment target — the `@Model` write (which forces
>   macOS 14) is part of activation. Adds `SettingsStore.exists(_:)`.
>   `needsMigration` defaults an absent `schemaVersion` to `1` (the shipped v1.x
>   never wrote it — the §2.2 "absent → fresh" assumption is corrected). 15 tests.
> - **`ChordSyncResolver`** (§7) — a local override wins locally; a failed
>   registration keeps the synced value and reports `showsDisabledCue`; persists
>   nothing (structurally cannot clobber the synced value). 6 tests. The
>   local-only `shortcutChordDeviceOverride` key + its migration-exclusion are
>   deferred to activation.
>
> **Activation (S8.5-gated) remaining for Phase 2:** bump deployment target to
> macOS 14; introduce the SwiftData `@Model` container + drive the snapshot into
> it; set `ModelConfiguration.cloudKitDatabase = .private(...)`; wire the
> resolvers into `CloudKitSyncEngine`; add the `shortcutChordDeviceOverride`
> local-only key (excluded from `SettingsMigration`). 658 tests green.

> **Phase 3 pure logic pre-built dark in S43 (2026-05-24).** Owner-confirmed
> pre-building the v2.1 Domain B merge ahead of v2.0 (same gate as S42; §12 Q5
> sequences Phase 3 as v2.1). Shipped as one inert pure value type in
> `Sources/Core`, fully unit-tested without iCloud — and, unlike Phase 2, with
> **no deployment-target cost** (no `@Model`, so macOS 13 holds):
> - **`ActivityLogMergeResolver`** — the append-only **union** merge for the
>   activity log (§4 B-2/§6), **never LWW**. `merge(_:)` unions any number of
>   device views, deduplicating by a stable **content-addressed id**
>   (`contentAddressedID` = SHA-256 of the immutable tuple → a valid
>   `CKRecord.recordName` with no further transform at activation), and returns a
>   single canonical order (timestamp, then id) so the merge is **commutative,
>   associative, and idempotent** as plain array equality (device wake order
>   cannot matter; re-syncing a merged set is a no-op). `pruned(_:now:retention:)`
>   mirrors `ActivityLogStore.gc` exactly (drop entries strictly older than
>   `now − retention`, keep the boundary; default tracks
>   `ActivityLogStore.defaultRetention` = 14 days) as a pure function with `now`
>   injected; `mergedAndPruned` is the full Domain B sync-in transform (union,
>   then local GC on the merged set — §4 B-2). 18 tests incl. the load-bearing
>   **never-LWW** guard (two Macs logging the same instant with distinct ids both
>   survive), content-addressed-id collision-freeness, and a Codable round-trip
>   stability check (the id must survive the on-disk `secondsSince1970` format or
>   dedup breaks). **No `ActivityLogEntry` model change**; CryptoKit is a system
>   framework, not CloudKit, so the §10 isolation guard stays green.
>
> **Activation (S8.5-gated) remaining for Phase 3:** create the CloudKit
> `activity-log` custom zone in the private DB; write each entry as a `CKRecord`
> named by `contentAddressedID`; feed downloaded records + the local JSON cache
> through `ActivityLogMergeResolver.mergedAndPruned` on sync-in; queue offline
> writes and flush on reconnect. The on-disk JSON stays the local cache / offline
> buffer (§4 B-2). 676 tests green.

---

## §12. Owner decisions — DECIDED 2026-05-18 (S38)

The three code-gating questions were answered by the owner on 2026-05-18.
Recorded verbatim so a future implementation session inherits the design
contract without re-litigation.

1. **Activity-log scope** — **DECIDED: B-2** (multi-device history, CloudKit
   custom-zone append-only union merge). Phase 3 is in scope. Rationale: C-3's
   value is cross-device visibility; the union-merge is a pure function and the
   structural data-loss guard is already designed (§4 B-2, §6, §10).
2. **Privacy questionnaire** — **DECIDED: approved.** Owner signs off on the
   §5.1 analysis: user-config strings (Wi-Fi SSIDs, app bundle IDs) landing
   only in the user's *own private* iCloud DB with no developer-side processing
   keeps the "No Data Collected" label. This is the owner/legal sign-off §5.1
   said was required; engineering may proceed on that basis. (Phase 4 still
   re-confirms the App Store privacy answer before public ship — §11.)
3. **v2.0 trigger** — **RESOLVED by Q5**: the OQ-04 migration *is* v2.0
   (v2.0 = Phase 1+2). No separate decision needed; release sequencing only.
4. **Container id** `iCloud.com.parkbyeongjun.latte` — **OPEN, non-gating.**
   Default proposal stands; owner accepts at Phase 1 kickoff unless V2-20
   changes the bundle prefix first (coupling tracked in §9). Does not block
   Phase 1 code (the seam is protocol-injected; the literal lives in one
   adapter + the entitlement file).
5. **Phase ordering** — **DECIDED: v2.0 = Phase 1 + Phase 2; Phase 3 = v2.1.**
   Phase 1 ships dark (zero behaviour change). Phase 2 (Settings + B1.2 chord)
   is the higher-value / lower-data-risk domain → clean v2.0. Phase 3
   (activity-log union merge) is independent (§11) and gets its own bake as
   v2.1 to bound blast radius of the append-only merge path.

**Gate state:** Q1/Q2/Q5 answered → **Phase 1 is unblocked** (dark, no
behaviour change, pure-unit-testable per §10; entitlement file only, container
stubbable until S8.5 — §11). Phase 2/3 remain **S8.5-gated** (live CloudKit
needs the Apple Developer Program). Q4 is the only remaining open item and is
non-gating.

---

## §13. Out of scope for this RFC (tracked, not done)

- **04-data-model §5 enum staleness** — ✅ **resolved in S38** (the §5 snapshot
  was refreshed to the full key set + an "`allCases` is authoritative" pointer).
  Flagged here at S37 when it still predated ~7 shipped keys; left as a tracked
  doc-tidy then, done since. This RFC references `SettingsKey.allCases` as the
  source of truth either way, so the migration was never at risk.
- **Actual privacy.html / App Store privacy-answer edits** — Phase 4, owner-side.
- **iOS companion / cross-device beyond Macs** — PRD §6.7 revenue-gated; far
  out, unaffected.
- Any code. This is design only.

---

## §14. One-paragraph summary for the next session

iCloud sync is **one entitlement/migration event covering two independent
domains**: Settings (SwiftData + CloudKit private DB, LWW, per OQ-04 — includes
the B1.2 chord with a per-device best-effort registration + optional non-synced
override) and the Activity log (recommended: CloudKit custom-zone **append-only
union merge**, never LWW, immutable content-addressed entries, local 14-day GC
on the merged set). "No Data Collected" is preserved because everything lands in
the *user's own private* iCloud DB with no developer-side processing and the
existing structured-reasonCode discipline already excludes all PII. Blocks on
S8.5 (Apple Dev Program). Risk-bearing logic (merge/LWW/migration/chord
fallback) is fully pure-unit-testable behind a `CloudSyncEngine` protocol seam
following the codebase's existing mock pattern; only final two-Mac confirmation
is owner-gated. Ships dark behind a compile-time kill-switch. **§12 Q1/Q2/Q5
were answered 2026-05-18 (Q1=B-2, Q2=approved, Q5=v2.0[Phase 1+2]/v2.1[Phase
3]): Phase 1 is now an actionable autonomous session; Phase ≥ 2 stays
S8.5-gated.**
