import SwiftUI

/// First-run wizard. Four short steps:
/// 1. Language — pick UI language (S32 Phase D). Writes
///    AppleLanguages; visible effect lands on the next launch.
/// 2. Welcome — explain the wedge in two sentences.
/// 3. Pick triggers — let the user enable any of the context
///    triggers; permission is requested when they confirm.
/// 4. Done — confirm + dismiss.
///
/// The wizard never blocks: at any step the user can hit "Skip" and
/// the app falls through to the menu bar with no triggers enabled
/// (recoverable via Settings → Triggers later).
public struct OnboardingView: View {

    @ObservedObject var state: OnboardingState
    @ObservedObject var coordinator: TriggerCoordinator
    @EnvironmentObject private var environment: AppEnvironment
    let onClose: () -> Void

    @State private var step: Step = .language
    @State private var pendingEnables: Set<String> = []
    @State private var isApplying: Bool = false
    @State private var selectedLanguage: String = LanguagePreference.current()

    public init(
        state: OnboardingState,
        coordinator: TriggerCoordinator,
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.coordinator = coordinator
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
            Divider()
            footer
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Content per step

    @ViewBuilder
    private var content: some View {
        switch step {
        case .language: languageStep
        case .welcome: welcomeStep
        case .pickTriggers: triggerStep
        case .done: doneStep
        }
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose your language")
                    .font(Theme.Fonts.title)
                Text("Latte will restart in this language on next launch. You can change this any time in Settings.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                              GridItem(.flexible(), spacing: Theme.Spacing.sm)],
                    spacing: Theme.Spacing.sm
                ) {
                    ForEach(LanguagePreference.supported) { option in
                        LanguageOnboardingButton(
                            option: option,
                            isSelected: selectedLanguage == option.code,
                            onTap: { selectLanguage(option.code) }
                        )
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    private func selectLanguage(_ code: String) {
        selectedLanguage = code
        LanguagePreference.apply(code)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.md) {
                CoffeeCupView(
                    isAwake: true,
                    fillRatio: 0.85,
                    liquidColor: environment.coffeeAccent.color
                )
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Latte")
                        .font(Theme.Fonts.title)
                    Text("Never let your Mac sleep at the wrong moment.")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Other caffeine apps make you remember to toggle them. Latte watches your context — calendar, running apps, Wi-Fi, Focus mode — and decides for you.")
                    .font(Theme.Fonts.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pick which contexts should keep your Mac awake. You can change anything later from Settings.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var triggerStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Pick what should keep your Mac awake")
                .font(Theme.Fonts.title)
            Text("Tap a card to enable. You can pick more than one.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(coordinator.triggers, id: \.id) { trigger in
                        TriggerOnboardingCard(
                            trigger: trigger,
                            description: description(for: trigger.id),
                            isSelected: pendingEnables.contains(trigger.id),
                            onToggle: { togglePending(trigger.id) }
                        )
                    }
                }
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(environment.coffeeAccent.color)
            VStack(spacing: Theme.Spacing.sm) {
                Text("You're all set")
                    .font(Theme.Fonts.title)
                Text(doneSummary)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Find Latte in the menu bar. Settings live behind \u{2318}, — adjust triggers, appearance, and Launch at Login any time.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private var doneSummary: String {
        if pendingEnables.isEmpty {
            return "Latte will start in manual mode. You can enable triggers any time from Settings → Triggers."
        }
        let names = coordinator.triggers
            .filter { pendingEnables.contains($0.id) }
            .map(\.displayName)
            .joined(separator: ", ")
        return "Latte will keep your Mac awake based on: \(names)."
    }

    // MARK: - Footer (Skip / Back / Continue)

    @ViewBuilder
    private var footer: some View {
        HStack {
            Button("Skip") {
                Task { await skipAll() }
            }
            .buttonStyle(.borderless)
            .disabled(isApplying)

            Spacer()

            if step != .language && step != .welcome {
                Button("Back") {
                    step = step.previous
                }
                .buttonStyle(.bordered)
                .disabled(isApplying)
            }

            Button(continueButtonTitle) {
                Task { await advance() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isApplying)
        }
    }

    private var continueButtonTitle: String {
        switch step {
        case .language: return "Continue"
        case .welcome: return "Continue"
        case .pickTriggers: return "Apply"
        case .done: return "Open Latte"
        }
    }

    // MARK: - Actions

    private func togglePending(_ id: String) {
        if pendingEnables.contains(id) {
            pendingEnables.remove(id)
        } else {
            pendingEnables.insert(id)
        }
    }

    private func advance() async {
        switch step {
        case .language:
            step = .welcome
        case .welcome:
            step = .pickTriggers
        case .pickTriggers:
            await applyPending()
            step = .done
        case .done:
            state.markCompleted()
            onClose()
        }
    }

    private func skipAll() async {
        // Clear any pending choices and finalize without enabling
        // anything. The user can revisit from Settings → Triggers.
        pendingEnables.removeAll()
        state.markCompleted()
        onClose()
    }

    private func applyPending() async {
        isApplying = true
        defer { isApplying = false }
        for trigger in coordinator.triggers where pendingEnables.contains(trigger.id) {
            trigger.isEnabled = true
            if trigger.requiresPermission {
                let granted = await trigger.requestPermissionIfNeeded()
                if !granted {
                    // Permission denied: keep `isEnabled = true` so the
                    // user sees the row in Settings → Triggers; the
                    // permission status footer copy will explain how
                    // to recover. Per the existing trigger-coordinator
                    // contract, we still call start so the next launch
                    // re-checks status.
                    continue
                }
            }
            await coordinator.start(trigger)
        }
    }

    // MARK: - Static descriptions

    private func description(for triggerID: String) -> String {
        switch triggerID {
        case "calendar":
            return "During scheduled meetings on your calendars."
        case "app":
            return "While Zoom, Teams, or any app you choose is running."
        case "wifi":
            return "Only on networks you trust (or never on networks you avoid)."
        case "focus":
            return "While any macOS Focus mode is active."
        case "schedule":
            return "On a recurring time schedule (e.g. weekday working hours)."
        default:
            return ""
        }
    }
}

// MARK: - Step enum

extension OnboardingView {

    enum Step: Int, CaseIterable {
        case language
        case welcome
        case pickTriggers
        case done

        var previous: Step {
            switch self {
            case .language: return .language
            case .welcome: return .language
            case .pickTriggers: return .welcome
            case .done: return .pickTriggers
            }
        }
    }
}

// MARK: - LanguageOnboardingButton

private struct LanguageOnboardingButton: View {

    let option: LanguagePreference.Option
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(option.nativeName)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(environment.coffeeAccent.color)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(isSelected ? environment.coffeeAccent.color.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? environment.coffeeAccent.color.opacity(0.6) : Color.secondary.opacity(0.20),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.nativeName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - TriggerOnboardingCard

private struct TriggerOnboardingCard: View {

    let trigger: any Trigger
    let description: String
    let isSelected: Bool
    let onToggle: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(isSelected ? environment.coffeeAccent.color.opacity(0.18) : Color.secondary.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: trigger.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? environment.coffeeAccent.color : .primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(trigger.displayName)
                        .font(Theme.Fonts.body)
                    Text(description)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? environment.coffeeAccent.color : .secondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? environment.coffeeAccent.color.opacity(0.6) : Color.secondary.opacity(0.20),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(trigger.displayName), \(description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
