import Cocoa
import WebKit

/// Builds 320x200 previews: images are scaled, HTML and rendered markdown are
/// snapshotted in an offscreen web view. Everything else gets no thumbnail and
/// the panel shows a kind icon instead.
final class Thumbnailer: NSObject, WKNavigationDelegate {
    private let size = NSSize(width: 320, height: 200)
    private var pending: [(WKWebView, (NSImage?) -> Void)] = []
    private var queue: [(Artifact, (NSImage?) -> Void)] = []
    private var busy = false

    func make(for artifact: Artifact, completion: @escaping (NSImage?) -> Void) {
        switch artifact.kind {
        case .image:
            DispatchQueue.global(qos: .utility).async {
                let img = NSImage(contentsOf: artifact.url).map { self.scaled($0) }
                completion(img)
            }
        case .html, .markdown:
            DispatchQueue.main.async {
                self.queue.append((artifact, completion))
                self.drain()
            }
        default:
            completion(nil)
        }
    }

    private func drain() {
        guard !busy, let (artifact, completion) = queue.first else { return }
        queue.removeFirst()
        let url = artifact.openURL
        guard url.pathExtension.lowercased().hasPrefix("htm") else { completion(nil); drain(); return }
        busy = true
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
        web.navigationDelegate = self
        pending.append((web, completion))
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.busy, self.pending.first?.0 === web else { return }
            self.finish(web, image: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let conf = WKSnapshotConfiguration()
            conf.rect = CGRect(x: 0, y: 0, width: 1280, height: 800)
            webView.takeSnapshot(with: conf) { image, _ in
                self.finish(webView, image: image.map { self.scaled($0) })
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(webView, image: nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(webView, image: nil) }

    private func finish(_ web: WKWebView, image: NSImage?) {
        guard let idx = pending.firstIndex(where: { $0.0 === web }) else { return }
        let (_, completion) = pending.remove(at: idx)
        web.navigationDelegate = nil
        busy = false
        completion(image)
        drain()
    }

    private func scaled(_ image: NSImage) -> NSImage {
        let src = image.size
        guard src.width > 0, src.height > 0 else { return image }
        let scale = min(size.width / src.width, size.height / src.height, 1)
        let target = NSSize(width: max(1, src.width * scale), height: max(1, src.height * scale))
        let out = NSImage(size: target)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target), from: NSRect(origin: .zero, size: src), operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }
}
