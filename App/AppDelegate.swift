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
            (button.cell as? NSButtonCell)?.highlightsBy = []
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

    func popoverDidClose(_ notification: Notification) {
        anchorWindow?.orderOut(nil)
    }

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

    // Anchoring the popover to the status item button makes AppKit paint the
    // button in the accent colour for as long as the popover is open. Anchor
    // it to an invisible window sitting under the button instead.
    private var anchorWindow: NSWindow?

    @objc private func togglePanel(_ sender: Any?) {
        if popover.isShown { popover.performClose(sender); return }
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        store.reload()
        let screenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let anchor = anchorWindow ?? {
            let w = NSWindow(contentRect: screenRect, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .statusBar
            w.collectionBehavior = [.canJoinAllSpaces, .stationary]
            anchorWindow = w
            return w
        }()
        anchor.setFrame(screenRect, display: false)
        anchor.orderFrontRegardless()
        guard let anchorView = anchor.contentView else { return }
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
