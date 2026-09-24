import Foundation

enum ArtifactKind: String, Codable {
    case image, html, markdown, pdf, video, text, other

    static func of(_ url: URL) -> ArtifactKind {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp": return .image
        case "html", "htm": return .html
        case "md", "markdown": return .markdown
        case "pdf": return .pdf
        case "mov", "mp4", "webm", "mkv": return .video
        case "txt", "csv", "tsv", "json", "yaml", "yml", "log", "sql", "sh", "ts", "js", "swift", "rb", "py": return .text
        default: return .other
        }
    }

    var label: String {
        switch self {
        case .image: return "image"
        case .html: return "html"
        case .markdown: return "markdown"
        case .pdf: return "pdf"
        case .video: return "video"
        case .text: return "text"
        case .other: return "file"
        }
    }
}

struct Artifact: Codable, Identifiable, Equatable {
    let id: String
    let path: String
    let title: String
    let kind: ArtifactKind
    let addedAt: Date
    var renderedPath: String?

    var url: URL { URL(fileURLWithPath: path) }
    var renderedURL: URL? { renderedPath.map { URL(fileURLWithPath: $0) } }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    var openURL: URL {
        if kind == .markdown, let rendered = renderedURL, FileManager.default.fileExists(atPath: rendered.path) {
            return rendered
        }
        return url
    }
}

enum HandoffPaths {
    static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Handoff", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    static var indexFile: URL { supportDir.appendingPathComponent("index.json") }
    static var thumbsDir: URL {
        let dir = supportDir.appendingPathComponent("thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static let changedNotification = Notification.Name("io.github.seethruhead.handoff.indexChanged")
    static let retentionDays = 30
}

enum ArtifactIndex {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    static func load() -> [Artifact] {
        guard let data = try? Data(contentsOf: HandoffPaths.indexFile),
              let items = try? decoder.decode([Artifact].self, from: data) else { return [] }
        let cutoff = Date().addingTimeInterval(-Double(HandoffPaths.retentionDays) * 86_400)
        return items.filter { $0.addedAt > cutoff }.sorted { $0.addedAt > $1.addedAt }
    }

    static func save(_ items: [Artifact]) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: HandoffPaths.indexFile, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            HandoffPaths.changedNotification, object: nil, userInfo: nil, deliverImmediately: true)
    }

    static func add(_ artifact: Artifact) -> [Artifact] {
        let others = load().filter { $0.path != artifact.path }
        let items = [artifact] + others
        save(items)
        return items
    }

    static func remove(id: String) -> [Artifact] {
        let items = load().filter { $0.id != id }
        save(items)
        return items
    }

    static func make(url: URL, title: String?, renderedPath: String?) -> Artifact {
        Artifact(id: UUID().uuidString, path: url.path,
                 title: title?.isEmpty == false ? title! : url.lastPathComponent,
                 kind: ArtifactKind.of(url), addedAt: Date(), renderedPath: renderedPath)
    }
}
