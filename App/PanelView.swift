import SwiftUI

final class PanelState: ObservableObject {
    @Published var showingSettings = false
}

struct PanelView: View {
    @ObservedObject var store: ArtifactStore
    @ObservedObject var state: PanelState
    @ObservedObject var installer: Installer

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if state.showingSettings {
                    Button(action: { state.showingSettings = false }) { Label("Back", systemImage: "chevron.left") }
                        .buttonStyle(.borderless)
                    Text("Settings").font(.headline)
                } else {
                    Text("Handoff").font(.headline)
                }
                Spacer()
                if !state.showingSettings {
                    Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(action: { state.showingSettings = true }) { Image(systemName: "gearshape") }
                        .buttonStyle(.borderless).help("Settings")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider()
            if state.showingSettings {
                ScrollView { SettingsView(installer: installer).padding(.vertical, 6) }
            } else if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("Nothing handed off yet").font(.title3)
                    Text("Agents run  handoff <file>  and it shows up here.").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(store.groups) { group in
                            Section {
                                ForEach(group.items) { artifact in
                                    ArtifactRow(artifact: artifact, thumbnail: store.thumbnails[artifact.id], store: store)
                                    Divider().padding(.leading, 14)
                                }
                            } header: {
                                Text(group.label)
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.bar)
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("Clear list") { store.clear() }.disabled(store.items.isEmpty)
                Spacer()
                Text("Click opens · drag to Slack or a prompt").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ArtifactRow: View {
    let artifact: Artifact
    let thumbnail: NSImage?
    @ObservedObject var store: ArtifactStore
    @State private var hovering = false
    @State private var copied = false

    private static let time: DateFormatter = { let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f }()

    var body: some View {
        DragSource(fileURL: artifact.url, onClick: { store.open(artifact) }) {
            HStack(alignment: .top, spacing: 12) {
                preview
                VStack(alignment: .leading, spacing: 3) {
                    Text(artifact.title).font(.body.weight(.medium)).lineLimit(2)
                    Text("\(artifact.kind.label) · \(shortPath)").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    HStack(spacing: 10) {
                        Text(Self.time.string(from: artifact.addedAt)).font(.caption).foregroundStyle(.secondary)
                        if !artifact.exists { Text("file missing").font(.caption).foregroundStyle(.red) }
                        Spacer()
                        Button(copied ? "Copied" : "Copy") { store.copy(artifact); flash() }
                        Button("Path") { store.copyPath(artifact); flash() }
                        Menu {
                            Button("Open") { store.open(artifact) }
                            Button("Reveal in Finder") { store.reveal(artifact) }
                            Divider()
                            Button("Remove from list", role: .destructive) { store.remove(artifact) }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    }
                    .buttonStyle(.borderless).font(.caption)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(hovering ? Color.primary.opacity(0.05) : .clear)
            .contentShape(Rectangle())
        }
        .frame(height: 118)
        .onHover { hovering = $0 }
    }

    private var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let p = artifact.url.deletingLastPathComponent().path
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    @ViewBuilder private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06))
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit).padding(2)
            } else {
                Image(systemName: icon).font(.system(size: 30)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 156, height: 98)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var icon: String {
        switch artifact.kind {
        case .image: return "photo"
        case .html: return "globe"
        case .markdown: return "doc.richtext"
        case .pdf: return "doc.fill"
        case .video: return "film"
        case .text: return "doc.text"
        case .other: return "doc"
        }
    }

    private func flash() {
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}
