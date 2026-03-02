import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var searchPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupSearchPanel()
    }

    func showSearchWindow() {
        guard let panel = searchPanel else { return }
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func setupSearchPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .utilityWindow
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let placeholder = NSHostingView(rootView:
            Text("MojiSticker")
                .frame(width: 380, height: 520)
                .background(.ultraThinMaterial)
        )
        panel.contentView = placeholder
        self.searchPanel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - panel.frame.width - 20
        let y = screenFrame.maxY - panel.frame.height - 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
