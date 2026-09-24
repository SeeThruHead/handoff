import SwiftUI

struct SettingsView: View {
    @ObservedObject var installer: Installer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Handoff v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")").font(.headline)

            row(done: installer.cliInstalled,
                title: "Command line tool",
                detail: "Symlinks the bundled `handoff` binary to \(installer.cliLink.path). Agents call it to register, copy and open files.",
                button: installer.cliInstalled ? "Reinstall CLI" : "Install CLI") { installer.installCLI() }

            row(done: installer.skillInstalled,
                title: "Agent skill",
                detail: "Writes \(installer.skillFile.path) so Claude Code, Pi, Codex and OpenCode hand files off instead of printing paths.",
                button: installer.skillInstalled ? "Reinstall skill" : "Install skill") { installer.installSkill() }

            row(done: installer.loginInstalled,
                title: "Open at login",
                detail: "LaunchAgent at \(installer.launchAgent.lastPathComponent).",
                button: installer.loginInstalled ? "Disable" : "Enable") { installer.toggleLogin() }

            Divider()
            Text("Index: \(HandoffPaths.indexFile.path)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Text("Entries older than \(HandoffPaths.retentionDays) days drop off the list. Files are never deleted.").font(.caption).foregroundStyle(.secondary)
            if !installer.message.isEmpty { Text(installer.message).font(.caption).foregroundStyle(.blue) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(done: Bool, title: String, detail: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? .green : .secondary).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(button, action: action)
        }
    }
}
