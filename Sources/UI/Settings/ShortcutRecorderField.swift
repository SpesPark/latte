import AppKit
import Carbon.HIToolbox
import SwiftUI

/// SwiftUI wrapper around an `NSView` that captures the next chord pressed
/// by the user. Mirrors the spec §3 FSM:
///
///     idle → click → recording
///     recording → first non-modifier key with ≥1 required modifier → committed
///     recording → Escape / click outside / 5s idle → idle
///     committed → 1 frame later → idle
///
/// Pure SwiftUI key capture isn't reliable on macOS 13 — `KeyEquivalent`
/// based modifiers ride the menu hotkey path and miss `flagsChanged`
/// transitions. NSViewRepresentable + an NSResponder-based subview is the
/// pattern Spotlight pickers use; ~50 LOC, isolated to this file.
public struct ShortcutRecorderField: View {

    @ObservedObject var coordinator: KeyboardShortcutCoordinator

    @State private var isRecording = false
    @State private var validationMessage: String?

    public init(coordinator: KeyboardShortcutCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                RecorderRepresentable(
                    isRecording: $isRecording,
                    onChord: { chord in commit(chord: chord) },
                    onCancel: { cancel() },
                    currentGlyph: coordinator.chord.glyph
                )
                .frame(minWidth: 96, maxWidth: 140, minHeight: 24)
                // J refinement (B1.2 follow-up): dim the recorder when the
                // shortcut is disabled — the displayed glyph is otherwise
                // misleading (looks live, isn't). The recorder still
                // captures keys when clicked so the user can pre-pick
                // their chord before flipping the toggle on.
                .opacity(coordinator.isEnabled ? 1.0 : 0.5)
                .disabled(!coordinator.isEnabled)

                Button("Reset") {
                    coordinator.resetChord()
                    validationMessage = nil
                }
                .controlSize(.small)
                .disabled(coordinator.chord == .default || !coordinator.isEnabled)
                .help("Reset to the default \(KeyChord.default.glyph) shortcut.")
            }
            if let validationMessage {
                Text(validationMessage)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.red)
            } else if let conflictMessage {
                Text(conflictMessage)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.red)
            } else if isRecording {
                Text("Press the new shortcut. Esc cancels.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            } else if !coordinator.isEnabled {
                // J refinement: explain why the recorder is greyed out.
                // Cleared automatically when the toggle flips back on
                // (this branch only fires when isEnabled == false).
                Text("Enable the shortcut above to record a different chord.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Surfaces `coordinator.registrationError` as inline copy. Drops back to
    /// nil whenever the coordinator clears the error (next successful set).
    private var conflictMessage: String? {
        guard case let .alreadyInUse(chord) = coordinator.registrationError else {
            return nil
        }
        return "\(chord.glyph) is already used by another app or macOS — pick a different combination."
    }

    private func commit(chord: KeyChord) {
        if !chord.hasRequiredModifier {
            validationMessage = "Add ⌘, ⌃, or ⌥ — bare ⇧ alone won't work as a global shortcut."
            return
        }
        if ReservedChord.contains(chord) {
            validationMessage = "\(chord.glyph) is reserved by macOS — pick a different combination."
            return
        }
        validationMessage = nil
        coordinator.setChord(chord)
        // setChord rolls back on register failure and surfaces the rejected
        // chord on `coordinator.registrationError`. When that surfaces, leave
        // the field in recording state so the user can pick another chord
        // immediately; on success, drop back to idle.
        isRecording = coordinator.registrationError != nil
    }

    private func cancel() {
        validationMessage = nil
        coordinator.clearRegistrationError()
        isRecording = false
    }
}

// MARK: - NSViewRepresentable

private struct RecorderRepresentable: NSViewRepresentable {

    @Binding var isRecording: Bool
    let onChord: (KeyChord) -> Void
    let onCancel: () -> Void
    let currentGlyph: String

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.onChord = onChord
        v.onCancel = onCancel
        v.bindIsRecording { newValue in
            // Bounce through DispatchQueue so the @Binding write doesn't
            // happen during the AppKit event handling pass.
            DispatchQueue.main.async { self.isRecording = newValue }
        }
        return v
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.glyph = isRecording ? "Press shortcut…" : currentGlyph
        if isRecording != nsView.isRecording {
            if isRecording { nsView.beginRecording() } else { nsView.endRecording() }
        }
    }
}

private final class RecorderNSView: NSView {

    var onChord: ((KeyChord) -> Void)?
    var onCancel: (() -> Void)?

    private(set) var isRecording = false
    var glyph: String = "" {
        didSet { needsDisplay = true }
    }

    private var isRecordingObserver: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    func bindIsRecording(_ observer: @escaping (Bool) -> Void) {
        self.isRecordingObserver = observer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 5
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        // Esc cancels.
        if event.keyCode == UInt16(kVK_Escape) {
            endRecording()
            onCancel?()
            return
        }
        // Validation lives in `commit(chord:)` on the SwiftUI side. On success it
        // flips `isRecording = false` and updateNSView reconciles by calling
        // endRecording(); on validation failure it leaves `isRecording = true` so
        // the field stays armed for another attempt. Calling endRecording here
        // would desync the layers and re-enter recording on the next pass.
        let mods = carbonModifiers(from: event.modifierFlags)
        let chord = KeyChord(modifiers: mods, keyCode: UInt32(event.keyCode))
        onChord?(chord)
    }

    func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        isRecordingObserver?(true)
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        needsDisplay = true
    }

    func endRecording() {
        guard isRecording else { return }
        isRecording = false
        isRecordingObserver?(false)
        layer?.borderColor = NSColor.separatorColor.cgColor
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        endRecording()
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: glyph, attributes: attrs)
        let size = str.size()
        let origin = NSPoint(
            x: max(8, (bounds.width - size.width) / 2),
            y: (bounds.height - size.height) / 2
        )
        str.draw(at: origin)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command)  { m |= UInt32(KeyChord.cmdMask) }
        if flags.contains(.shift)    { m |= UInt32(KeyChord.shiftMask) }
        if flags.contains(.option)   { m |= UInt32(KeyChord.optionMask) }
        if flags.contains(.control)  { m |= UInt32(KeyChord.ctrlMask) }
        return m
    }
}
