import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = ArtifactStore()
    private let panelState = PanelState()
    private let installer = Installer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Handoff")
            button.image?.isTemplate = true
            button.action = #selector(togglePanel(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentSize = NSSize(width: 720, height: 560)
        let root = PanelView(store: store, state: panelState, installer: installer)
        popover.contentViewController = NSHostingController(rootView: root)

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(indexChanged), name: HandoffPaths.changedNotification, object: nil)
        store.reload()
        let env = ProcessInfo.processInfo.environment
        if env["HANDOFF_SHOW_ON_LAUNCH"] == "1" || env["HANDOFF_SNAPSHOT"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePanel(nil) }
        }
        if let snapshot = env["HANDOFF_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                self.writeSnapshot(to: snapshot)
                self.panelState.showingSettings = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.writeSnapshot(to: snapshot.replacingOccurrences(of: ".png", with: "-settings.png"))
                    self.panelState.showingSettings = false
                }
            }
        }
    }

    @objc private func indexChanged() { store.reload() }

    private func writeSnapshot(to path: String) {
        guard let view = popover.contentViewController?.view else { return }
        writeSnapshot(of: view, to: path)
    }

    private func writeSnapshot(of view: NSView, to path: String) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    @objc private func togglePanel(_ sender: Any?) {
        if popover.isShown { popover.performClose(sender); return }
        guard let button = statusItem.button else { return }
        store.reload()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
