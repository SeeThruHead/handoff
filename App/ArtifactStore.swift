import Cocoa
import Combine

final class ArtifactStore: ObservableObject {
    @Published private(set) var items: [Artifact] = []
    @Published private(set) var thumbnails: [String: NSImage] = [:]
    private let thumbnailer = Thumbnailer()

    struct DayGroup: Identifiable {
        let id: String
        let label: String
        let items: [Artifact]
    }

    var groups: [DayGroup] {
        let cal = Calendar.current
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
        let keyed = Dictionary(grouping: items) { cal.startOfDay(for: $0.addedAt) }
        return keyed.keys.sorted(by: >).map { day in
            let label = cal.isDateInToday(day) ? "Today" : cal.isDateInYesterday(day) ? "Yesterday" : df.string(from: day)
            return DayGroup(id: "\(day.timeIntervalSince1970)", label: label, items: keyed[day]!)
        }
    }

    func reload() {
        DispatchQueue.main.async {
            self.items = ArtifactIndex.load()
            self.items.forEach { self.ensureThumbnail(for: $0) }
        }
    }

    func remove(_ artifact: Artifact) {
        items = ArtifactIndex.remove(id: artifact.id)
        try? FileManager.default.removeItem(at: HandoffPaths.thumbsDir.appendingPathComponent("\(artifact.id).png"))
    }

    func clear() {
        ArtifactIndex.save([])
        items = []
        try? FileManager.default.removeItem(at: HandoffPaths.thumbsDir)
    }

    func open(_ artifact: Artifact) { NSWorkspace.shared.open(artifact.openURL) }
    func reveal(_ artifact: Artifact) { NSWorkspace.shared.activateFileViewerSelecting([artifact.url]) }
    func copy(_ artifact: Artifact) { HandoffPasteboard.copy(artifact.url) }
    func copyPath(_ artifact: Artifact) { HandoffPasteboard.copyPath(artifact.url) }

    private func ensureThumbnail(for artifact: Artifact) {
        guard thumbnails[artifact.id] == nil, artifact.exists else { return }
        let cached = HandoffPaths.thumbsDir.appendingPathComponent("\(artifact.id).png")
        if let img = NSImage(contentsOf: cached) { thumbnails[artifact.id] = img; return }
        thumbnailer.make(for: artifact) { [weak self] image in
            guard let self, let image else { return }
            if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: cached)
            }
            DispatchQueue.main.async { self.thumbnails[artifact.id] = image }
        }
    }
}
