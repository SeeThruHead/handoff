import Foundation
import Combine

/// The app bootstraps its own integration points: the bundled CLI, the agent
/// skill, and a LaunchAgent for login. Each reports its current state so the
/// settings view can show ticks instead of guesses.
final class Installer: ObservableObject {
    @Published var message = ""

    var bundledCLI: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/handoff") }
    var cliLink: URL {
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin"].map { URL(fileURLWithPath: $0) }
        if let dir = candidates.first(where: { FileManager.default.isWritableFile(atPath: $0.path) }) {
            return dir.appendingPathComponent("handoff")
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/handoff")
    }
    var skillFile: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agents/skills/handoff/SKILL.md") }
    var launchAgent: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/io.github.seethruhead.handoff.plist") }

    var cliInstalled: Bool {
        let resolved = cliLink.resolvingSymlinksInPath().path
        return FileManager.default.isExecutableFile(atPath: resolved) && resolved.hasSuffix("Handoff.app/Contents/Helpers/handoff")
    }
    var skillInstalled: Bool {
        guard let installed = try? String(contentsOf: skillFile), let bundled = bundledSkill() else { return false }
        return installed == bundled
    }
    var loginInstalled: Bool { FileManager.default.fileExists(atPath: launchAgent.path) }

    func bundledSkill() -> String? {
        guard let url = Bundle.main.url(forResource: "SKILL", withExtension: "md") else { return nil }
        return try? String(contentsOf: url)
    }

    func installCLI() {
        do {
            try FileManager.default.createDirectory(at: cliLink.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: cliLink.path) || (try? FileManager.default.destinationOfSymbolicLink(atPath: cliLink.path)) != nil {
                try FileManager.default.removeItem(at: cliLink)
            }
            try FileManager.default.createSymbolicLink(at: cliLink, withDestinationURL: bundledCLI)
            message = "CLI linked at \(cliLink.path)"
            if cliLink.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) { message += " (add ~/.local/bin to PATH if it is not already)" }
        } catch { message = "CLI install failed: \(error.localizedDescription)" }
        objectWillChange.send()
    }

    func installSkill() {
        guard let text = bundledSkill() else { message = "Bundled skill missing"; return }
        do {
            try FileManager.default.createDirectory(at: skillFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: skillFile, atomically: true, encoding: .utf8)
            message = "Skill written to \(skillFile.path)"
        } catch { message = "Skill install failed: \(error.localizedDescription)" }
        objectWillChange.send()
    }

    func toggleLogin() {
        if loginInstalled {
            try? FileManager.default.removeItem(at: launchAgent)
            message = "Open at login disabled"
        } else {
            let exe = Bundle.main.executablePath ?? "/Applications/Handoff.app/Contents/MacOS/Handoff"
            let plist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>io.github.seethruhead.handoff</string>
  <key>ProgramArguments</key><array><string>\(exe)</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict></plist>
"""
            try? FileManager.default.createDirectory(at: launchAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? plist.write(to: launchAgent, atomically: true, encoding: .utf8)
            message = "Open at login enabled"
        }
        objectWillChange.send()
    }
}
