import Cocoa

/// One pasteboard item, several representations: the file URL (Slack, Finder
/// paste the file), the POSIX path as text (terminals, Claude paste the path),
/// and PNG data for images (image fields paste the pixels).
enum HandoffPasteboard {
    static func item(for fileURL: URL) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(fileURL.absoluteString, forType: .fileURL)
        item.setString(fileURL.path, forType: .string)
        if ArtifactKind.of(fileURL) == .image,
           let image = NSImage(contentsOf: fileURL),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            item.setData(png, forType: .png)
        }
        return item
    }

    @discardableResult
    static func copy(_ fileURL: URL) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.writeObjects([item(for: fileURL)])
    }

    static func copyPath(_ fileURL: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(fileURL.path, forType: .string)
    }
}
