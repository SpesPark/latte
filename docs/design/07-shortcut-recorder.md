# 07 — Custom Keyboard-Shortcut Recorder Spec (B1.2)

| Field | Value |
|---|---|
| **Document version** | 1.0 |
| **Status** | ✅ Shipped in S12 (2026-04-30). See ROADMAP row 11b. |
| **Audience** | Implementing engineer for v1.2 |
| **Depends on** | B1 (`KeyboardShortcutCoordinator` + `CarbonHotKeyRegistrar`, shipped S9) |
| **Backlog ref** | `v2-backlog.md` B1.2 |
| **Last updated** | 2026-04-30 |

---

## 1. Purpose

v1.1 (B1) ships a fixed global hotkey **⌘⇧L**. v1.2 lets the user **rebind**
that chord through a small recorder UI in Settings → General.

### User signal

- The fixed-chord ship was a deliberate v1.1 cut: it gets the feature in users'
  hands without the recorder UX risk. Users on Reddit / KYA threads regularly
  ask "can I change this?" once a fixed-chord toggle ships.
- Conflict with system or other-app chords (especially in IDEs / VPN clients)
  is the #1 friction reported for similar tools.

### Out of scope (deferred)

- **Per-action chords** — only the awake-toggle gets a recorder. Pause-all,
  snooze, etc., stay menu-driven.
- **iCloud sync of the chord** — local-only setting. Sync would need
  CloudKit + conflict resolution.
- **Visual indicator that current chord is reserved by another app** —
  macOS can't enumerate other apps' Carbon registrations; we'd ship false
  negatives. Defer.

---

## 2. API surface (extends existing B1 plumbing)

### New: `KeyChord` value type

```swift
/// A captured chord — modifier mask + key code. Codable so it can round-trip
/// through `SettingsStore` as a single `String` (JSON), the same approach
/// used for `MenuBarIconStyle`.
public struct KeyChord: Codable, Hashable, Sendable {
    /// Carbon-style modifier mask: cmdKey, shiftKey, optionKey, controlKey.
    public let modifiers: UInt32
    /// Carbon virtual key code (kVK_ANSI_L = 0x25, etc.).
    public let keyCode: UInt32

    /// Human-readable glyph string, e.g. "⌘⇧L" — same format as
    /// `KeyboardShortcutCoordinator.chordGlyph`.
    public var glyph: String { ... }

    public static let `default`: KeyChord
        = KeyChord(modifiers: UInt32(cmdKey | shiftKey),
                   keyCode: UInt32(kVK_ANSI_L))
}
```

### Extended: `HotKeyRegistrar` protocol

Add a parameterized `register`:

```swift
public protocol HotKeyRegistrar: AnyObject {
    /// Register a specific chord. Replaces any prior registration.
    func register(chord: KeyChord, handler: @escaping @MainActor () -> Void)

    func unregister()
    var isRegistered: Bool { get }
    var currentChord: KeyChord? { get }   // NEW — for UI status
}
```

The B1 `register(handler:)` signature gets a default-impl shim that calls
`register(chord: .default, handler:)` so existing call sites keep working
during the transition.

### Extended: `KeyboardShortcutCoordinator`

```swift
@MainActor
public final class KeyboardShortcutCoordinator: ObservableObject {

    @Published public private(set) var chord: KeyChord
    @Published public private(set) var isRegistered: Bool

    public init(settings: SettingsStore,
                registrar: HotKeyRegistrar = CarbonHotKeyRegistrar(),
                onToggleAwake: @escaping @MainActor () -> Void)

    /// Persist + re-register. Idempotent if `newChord == chord`.
    public func setChord(_ newChord: KeyChord)

    /// Reset to ⌘⇧L (used by Settings "Reset to default" button).
    public func resetChord()
}
```

Persistence: new `SettingsKey.shortcutChord` (JSON-encoded `KeyChord`).
Default = `.default` (⌘⇧L).

---

## 3. Recorder UI

`Sources/UI/Settings/ShortcutRecorderField.swift` (new):

```
┌────────────────────────────────────┐
│  Toggle awake                  [⌘⇧L]│  ← current chord, click to record
│                                     │
│  Press the new shortcut…       [Esc]│  ← state during recording
│                                     │
│  ⌘⇧L is reserved by Logic Pro       │  ← (optional) collision warning
└────────────────────────────────────┘
                                  [Reset]
```

### States (FSM)

| State | Trigger | Next |
|---|---|---|
| idle | click on field | recording |
| recording | first non-modifier key down with ≥1 modifier held | committed |
| recording | Escape, click outside, or 5s idle | idle |
| committed | — | idle (auto-return after 1 frame) |

### Validation

- **Minimum**: 1 modifier (⌘ or ⌃ or ⌥ — bare ⇧ not enough; bare letter never).
- **Reserved chords blocked**: ⌘Q, ⌘W, ⌘C/V/X (system-clipboard), ⌘Tab,
  ⌘Space (Spotlight). Show inline error, stay in `recording` until valid.
- If `RegisterEventHotKey` returns a non-`noErr` status (chord already taken
  globally), show "This shortcut is already in use by another app — choose
  another" and revert to the prior chord.

### Implementation note

Pure SwiftUI key capture is not robust on macOS 13. Use a thin `NSViewRepresentable`
wrapping an `NSView` with an `NSResponder`-based keyDown handler — same
approach Spotlight pickers use. ~50 LOC, isolated.

---

## 4. State-machine impact

**None.** B1.2 only adds a value-type setting + UI; the awake FSM is unchanged.

---

## 5. Test plan

### `Tests/KeyChordTests.swift` (NEW) — ≥ 6 tests

1. `default_chord_is_cmd_shift_L`
2. `glyph_renders_modifiers_in_canonical_order_cmd_opt_ctrl_shift_letter`
3. `codable_roundtrip_preserves_modifiers_and_keycode`
4. `decode_garbage_returns_nil` (lenient — `KeyChord?`)
5. `equal_chord_compares_equal`
6. `chord_with_only_shift_modifier_is_rejected_at_validation_layer`

### `Tests/KeyboardShortcutCoordinatorTests.swift` (extend, +5 tests)

7. `setChord_persists_to_store_and_re_registers_with_mock`
8. `setChord_with_same_value_is_no_op_no_re_register` (idempotence)
9. `resetChord_returns_to_default_and_re_registers`
10. `init_hydrates_chord_from_store_when_present`
11. `init_falls_back_to_default_when_stored_value_is_garbage`

### `Tests/MockHotKeyRegistrar.swift` (extend)

- Add `register(chord:handler:)` overload + `currentChord` property to
  observe what was last registered.
- Track register-call count for idempotence test.

### Coordinator integration (optional, +1 test)

- `coordinator_publishes_isRegistered_false_when_register_fails` — pass a
  failing-mock and assert the `@Published var isRegistered` flips false.

---

## 6. Smoke plan

`.smoke/scenarios/21-shortcut-recorder.sh` (NEW):

- Launch Latte, open Settings → General → Shortcut row.
- Capture window screenshot showing the default `⌘⇧L` glyph.
- (Manual-only, can't script keyDown into the recorder field with current
  harness.) Document as INFO line that recorder interaction is owner-side.
- Verify `defaults read com.parkbyeongjun.latte shortcutChord` is empty by
  default (since default chord isn't persisted until user-customised).

For full recorder validation, owner manual smoke is the source of truth:
1. Open Settings → General → Shortcut.
2. Click the field; press ⌘⌥K. Field should show `⌘⌥K`.
3. Quit Latte; reopen. Field should still show `⌘⌥K`.
4. Press ⌘⌥K from another app; awake state should toggle.
5. Click "Reset"; field should revert to `⌘⇧L`.

---

## 7. Effort estimate

| Phase | Hours |
|---|---|
| `KeyChord` + Codable + glyph rendering | 0.5 |
| `HotKeyRegistrar` protocol extension + `CarbonHotKeyRegistrar` chord param | 0.5 |
| `KeyboardShortcutCoordinator` `setChord` / `resetChord` / `@Published chord` | 0.5 |
| `ShortcutRecorderField` (NSViewRepresentable + state FSM) | 1.5 |
| Settings UI integration + Reset button | 0.3 |
| Tests (12 unit + 1 integration) | 1.0 |
| Smoke scenario 21 | 0.2 |
| Reserved-chord validation list + collision UI | 0.5 |
| **Total** | **~5.0 h** |

Larger than V2-06 (~4h) because of the `NSViewRepresentable` recorder.

---

## 8. Open questions for owner

| # | Question | Default |
|---|---|---|
| Q1 | Reserved-chord blocklist scope: system-only, or include common app chords (e.g. IDEs)? | **System-only** — IDE chord conflicts are user's choice; we surface the OS-level rejection from `RegisterEventHotKey`. |
| Q2 | "Empty chord" state allowed (= no global hotkey)? | **No** — always have a chord; user uses Reset to go back to default. Simpler UX. |
| Q3 | Show the chord in the menubar tooltip? | **Yes** — existing tooltip already includes hint; just bind to `coordinator.chord.glyph`. |
| Q4 | Migration: pre-v1.2 users have no `shortcutChord` key — silent default? | **Yes** — `init` falls back to `.default`; no migration banner. |

---

## 9. Cross-references

- B1 commit chain (S9): `f1fbc1d` family — sets up `KeyboardShortcutCoordinator`, `CarbonHotKeyRegistrar`, MockHotKeyRegistrar, ⌘⇧L plumbing.
- 02-architecture.md §3.1 (folder layout) — recorder lives in `UI/Settings/`.
- v2-backlog.md B1.2 — this spec replaces the one-line backlog entry.

---

## 10. Implementation order — **as shipped in S12**

Three-commit sequence landed 2026-04-30 (continuation of the same-day
S11 / V2-06 ship):

1. `f3d1b24` — **Core RED+GREEN**: `KeyChord` value type + `ReservedChord`
   blocklist + `SettingsStore` keyChord round-trip helpers + extended
   `HotKeyRegistrar` protocol (`register(chord:handler:)`,
   `currentChord`) + `KeyboardShortcutCoordinator.@Published chord`
   / `setChord` / `resetChord`. 14 new tests (7 `KeyChordTests` + 7
   coordinator chord-management). Spec test #4 reframed via the
   `SettingsStore` extension because the lenient form lives there
   rather than directly on `KeyChord`.
2. `d7e4a97` — **UI**: `ShortcutRecorderField` SwiftUI wrapper around
   an `NSResponder`-based `NSView` (Spotlight-picker pattern). Inline
   FSM (idle / recording) tracked through `@State isRecording` + an
   observer callback into the NSView. Reserved-chord and
   missing-modifier validation surfaces inline red copy and keeps the
   field in `recording` until valid. `GeneralTab` gains a "Shortcut"
   `LabeledContent` row directly under the existing toggle; the
   toggle's label switched from `KeyboardShortcutCoordinator.chordGlyph`
   (compile-time default) to `environment.keyboardShortcut.chord.glyph`
   (live).
3. *(this commit)* — **Smoke + docs**: scenario 21 covers the
   silent-default migration + Settings capture for owner review;
   ROADMAP row 11b; v2-backlog B1.2 marked Shipped; this spec marked
   1.0 / Shipped.

The `CarbonHotKeyRegistrar` log line was switched from the hardcoded
"⌘⇧L" string to `chord.glyph` so the structured log telemetry stays
honest after the user customises.

The optional integration test from §5 ("coordinator publishes
isRegistered=false when register fails") landed as
`testRegistrarFailureLeavesIsRegisteredFalse` — exercises the new
`failNextRegister` toggle on `MockHotKeyRegistrar`.
