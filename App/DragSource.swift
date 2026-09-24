import Cocoa
import SwiftUI

/// Wraps a row so it can be dragged out of the panel carrying the same
/// pasteboard item as the clipboard: file URL, path text, PNG for images.
struct DragSource<Content: View>: NSViewRepresentable {
    let fileURL: URL
    let onClick: () -> Void
    let content: Content

    init(fileURL: URL, onClick: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.fileURL = fileURL; self.onClick = onClick; self.content = content()
    }

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.fileURL = fileURL
        view.onClick = onClick
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        view.host = host
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.fileURL = fileURL
        view.onClick = onClick
        view.host?.rootView = content
    }

    final class DragView: NSView, NSDraggingSource {
        var fileURL: URL!
        var onClick: (() -> Void)?
        var host: NSHostingView<Content>?
        private var downAt: NSPoint?

        override func mouseDown(with event: NSEvent) { downAt = event.locationInWindow }

        override func mouseDragged(with event: NSEvent) {
            guard let start = downAt, hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) > 4 else { return }
            downAt = nil
            let item = NSDraggingItem(pasteboardWriter: HandoffPasteboard.item(for: fileURL))
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = NSSize(width: 64, height: 64)
            let origin = NSPoint(x: convert(event.locationInWindow, from: nil).x - 32, y: convert(event.locationInWindow, from: nil).y - 32)
            item.setDraggingFrame(NSRect(origin: origin, size: icon.size), contents: icon)
            beginDraggingSession(with: [item], event: event, source: self)
        }

        override func mouseUp(with event: NSEvent) {
            if downAt != nil { onClick?() }
            downAt = nil
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    }
}
