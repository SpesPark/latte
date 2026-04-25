import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var awake: AwakeManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("activateOnLaunch") private var activateOnLaunch = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            triggersTab
                .tabItem { Label("Triggers", systemImage: "bolt.badge.clock") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 340)
    }

    private var generalTab: some View {
        Form {
            Section("Behavior") {
                Toggle("Allow display sleep (system stays awake)",
                       isOn: $awake.allowDisplaySleep)
                Toggle("Activate on launch", isOn: $activateOnLaunch)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .disabled(true) // Phase 1.0 — wire up via ServiceManagement
            }

            Section {
                Text("Toggle the menu bar icon to caffeinate on demand, or pick a preset duration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var triggersTab: some View {
        Form {
            Section("Coming in Phase A") {
                Label("Calendar — auto-awake during meetings", systemImage: "calendar")
                    .foregroundStyle(.secondary)
                Label("Apps — Zoom, Teams, Final Cut, …", systemImage: "app.badge")
                    .foregroundStyle(.secondary)
                Label("Wi-Fi — specific networks", systemImage: "wifi")
                    .foregroundStyle(.secondary)
                Label("Focus — Work mode", systemImage: "moon.stars")
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Triggers are scaffolded under `Sources/Triggers/`. Implement each trigger's `start()`/`stop()` to activate the awake manager automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            CoffeeCupView(isActive: true)
                .scaleEffect(1.6)
                .padding(.top, 24)
            Text("Caffeinated")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Version 0.1.0 · MVP")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Built with SwiftUI · macOS 13+")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AwakeManager.shared)
}
