import Cocoa

let usage = """
usage: handoff <file> [--title "..."] [--no-open] [--no-copy]
       handoff put <file> [--title "..."]      register + copy to clipboard, do not open
       handoff open <file> [--title "..."]     register + open, do not copy
       handoff list                            print the current index

Registers the file with the Handoff tray app, copies it to the clipboard as one
item (file URL, path text, PNG for images) and opens the original file in its
default app. Nothing is written next to it.
"""

var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty, !args.contains("-h"), !args.contains("--help") else {
    print(usage); exit(args.isEmpty ? 2 : 0)
}

var doOpen = true
var doCopy = true
if args.first == "put" { doOpen = false; args.removeFirst() }
else if args.first == "open" { doCopy = false; args.removeFirst() }
else if args.first == "list" {
    let f = ISO8601DateFormatter()
    ArtifactIndex.load().forEach { print("\(f.string(from: $0.addedAt))\t\($0.kind.label)\t\($0.title)\t\($0.path)") }
    exit(0)
}

var title: String?
var positional: [String] = []
var i = 0
while i < args.count {
    switch args[i] {
    case "--title": title = i + 1 < args.count ? args[i + 1] : nil; i += 2
    case "--no-open": doOpen = false; i += 1
    case "--no-copy": doCopy = false; i += 1
    default: positional.append(args[i]); i += 1
    }
}

guard let rawPath = positional.first else {
    FileHandle.standardError.write("handoff: missing file\n\(usage)\n".data(using: .utf8)!); exit(2)
}
let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
guard FileManager.default.fileExists(atPath: url.path) else {
    FileHandle.standardError.write("handoff: no such file: \(url.path)\n".data(using: .utf8)!); exit(1)
}

let kind = ArtifactKind.of(url)
let artifact = ArtifactIndex.make(url: url, title: title, renderedPath: nil)
_ = ArtifactIndex.add(artifact)

if doCopy {
    if HandoffPasteboard.copy(url) { print("copied: \(url.path)") }
    else { FileHandle.standardError.write("handoff: clipboard write failed\n".data(using: .utf8)!) }
}
if doOpen {
    let target = artifact.openURL
    NSWorkspace.shared.open(target)
    print("opened: \(target.path)")
}
print("registered: \(artifact.title) [\(kind.label)]")
