import Foundation

enum Render {
    static func findExecutable(_ name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "/usr/bin"]
        return candidates.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Renders markdown to a sibling .html with grip. Returns the rendered path, or nil if grip is missing or fails.
    static func markdown(_ url: URL) -> URL? {
        guard let grip = findExecutable("grip") else { return nil }
        let out = url.deletingPathExtension().appendingPathExtension("html")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: grip)
        process.arguments = [url.path, "--export", out.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch { return nil }
        return process.terminationStatus == 0 && FileManager.default.fileExists(atPath: out.path) ? out : nil
    }
}
